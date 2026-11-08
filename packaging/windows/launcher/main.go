// geban-launcher — bootstrap do GEBAN all-in-one para Windows.
//
// Sobe, nesta ordem, sem exigir terminal nem administrador:
//  1. PostgreSQL embarcado (pg/bin do instalador): initdb na primeira
//     execução, pg_ctl start nas demais;
//  2. `advplc.exe serve src/GEBTUI.prw` (interface web local :8081);
//  3. `advplc.exe run src/GEBWEB.prw` (API REST :8090);
//  4. tarefa agendada "GEBAN Scheduler" (GEBSCHJOB a cada minuto);
//  5. navegador em http://127.0.0.1:8081.
//
// Dados e configuração ficam em <instalacao>\data e geban.env —
// instalação por-usuário (%LocalAppData%\GEBAN), sem serviço Windows.
package main

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

const (
	createNoWindow = 0x08000000 // CREATE_NO_WINDOW (não exportada pelo stdlib)
	pgPort         = "5432"
	pgDB           = "geban"
	pgUser         = "geban_app"
)

type config struct {
	Dir     string // diretório do executável (instalação)
	DataDir string // <dir>\data
	EnvFile string // <dir>\geban.env
}

var children []*exec.Cmd

func main() {
	// --autostart (chave Run do logon): se a UI já responde, outra
	// instância está no ar — sai em silêncio em vez de subir tudo de novo.
	if len(os.Args) > 1 && os.Args[1] == "--autostart" {
		if c, err := net.DialTimeout("tcp", "127.0.0.1:8081", 500*time.Millisecond); err == nil {
			c.Close()
			os.Exit(0)
		}
	}
	cfg, err := loadConfig()
	if err != nil {
		fatal("config: %v", err)
	}
	logf("GEBAN launcher — dir=%s", cfg.Dir)

	if err := run(cfg); err != nil {
		fatal("%v", err)
	}

	// Fica vivo supervisionando; ao receber Ctrl+C/fechamento, derruba os filhos.
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	<-c
	logf("encerrando processos filhos...")
	for _, cmd := range children {
		if cmd.Process != nil {
			cmd.Process.Kill()
		}
	}
}

func run(cfg *config) error {
	if err := ensurePostgres(cfg); err != nil {
		return fmt.Errorf("postgres: %w", err)
	}
	if err := provisionDB(cfg); err != nil {
		return fmt.Errorf("banco: %w", err)
	}
	if err := startChildren(cfg); err != nil {
		return err
	}
	if err := ensureScheduler(cfg); err != nil {
		logf("aviso: scheduler não configurado: %v", err)
	}
	go openBrowserWhenReady()
	return nil
}

func loadConfig() (*config, error) {
	exe, err := os.Executable()
	if err != nil {
		return nil, err
	}
	dir := filepath.Dir(exe)
	return &config{
		Dir:     dir,
		DataDir: filepath.Join(dir, "data"),
		EnvFile: filepath.Join(dir, "geban.env"),
	}, nil
}

// ---------- PostgreSQL embarcado ----------

func pgBin(cfg *config, name string) string {
	return filepath.Join(cfg.Dir, "pg", "bin", name)
}

func ensurePostgres(cfg *config) error {
	pgCtl := pgBin(cfg, "pg_ctl.exe")
	if _, err := os.Stat(pgCtl); err != nil {
		return fmt.Errorf("pg_ctl.exe não encontrado em %s", filepath.Dir(pgCtl))
	}
	pgData := filepath.Join(cfg.DataDir, "pg")
	firstRun := false
	if _, err := os.Stat(pgData); os.IsNotExist(err) {
		firstRun = true
	} else if err != nil {
		return err
	}

	if firstRun {
		if err := os.MkdirAll(pgData, 0700); err != nil {
			return err
		}
		pw, err := randomPassword()
		if err != nil {
			return err
		}
		pwFile := filepath.Join(cfg.DataDir, "pgpass.tmp")
		if err := os.WriteFile(pwFile, []byte(pw+"\n"), 0600); err != nil {
			return err
		}
		defer os.Remove(pwFile)
		out, err := runCmd(pgBin(cfg, "initdb.exe"),
			"-D", pgData, "-U", "postgres", "--pwfile="+pwFile,
			"--encoding=UTF8", "--locale=C")
		if err != nil {
			return fmt.Errorf("initdb: %v\n%s", err, out)
		}
		hba := filepath.Join(pgData, "pg_hba.conf")
		if err := os.WriteFile(hba, []byte(
			"local   all             all                                     scram-sha-256\n"+
				"host    all             all             127.0.0.1/32            scram-sha-256\n"+
				"host    all             all             ::1/128                 scram-sha-256\n"), 0600); err != nil {
			return err
		}
		if err := writeEnvFile(cfg, map[string]string{"GEBAN_PG_PASS": pw}); err != nil {
			return err
		}
		logf("initdb concluído")
	}

	if pgReady() {
		logf("postgres já está rodando")
		return nil
	}
	logf("iniciando postgres…")
	out, err := runCmd(pgCtl,
		"-D", pgData,
		"-l", filepath.Join(cfg.DataDir, "postgres.log"),
		"-o", "-p "+pgPort+" -c listen_addresses=127.0.0.1",
		"-w", "start")
	if err != nil {
		return fmt.Errorf("pg_ctl start: %v\n%s", err, out)
	}
	for i := 0; i < 30; i++ {
		if pgReady() {
			logf("postgres pronto")
			return nil
		}
		time.Sleep(time.Second)
	}
	return fmt.Errorf("postgres não respondeu em 30s (ver data\\postgres.log)")
}

func pgReady() bool {
	c, err := net.DialTimeout("tcp", "127.0.0.1:"+pgPort, time.Second)
	if err != nil {
		return false
	}
	c.Close()
	return true
}

// ---------- banco lógico (role + database da aplicação) ----------

func provisionDB(cfg *config) error {
	appPass := readEnvValue(cfg.EnvFile, "GEBAN_PG_PASSWORD")
	if appPass == "" {
		p, err := randomPassword()
		if err != nil {
			return err
		}
		appPass = p
	}
	suPass := readEnvValue(cfg.EnvFile, "GEBAN_PG_PASS")
	if suPass == "" {
		return fmt.Errorf("GEBAN_PG_PASS ausente em %s (rode initdb antes)", cfg.EnvFile)
	}

	sql := fmt.Sprintf(
		"DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='%s') THEN CREATE ROLE %s LOGIN PASSWORD '%s'; ELSE ALTER ROLE %s LOGIN PASSWORD '%s'; END IF; END $$;"+
			"SELECT 'CREATE DATABASE %s OWNER %s' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname='%s')\\gexec",
		pgUser, pgUser, appPass, pgUser, appPass, pgDB, pgUser, pgDB)

	cmd := exec.Command(pgBin(cfg, "psql.exe"),
		"-h", "127.0.0.1", "-p", pgPort, "-U", "postgres", "-d", "postgres",
		"-v", "ON_ERROR_STOP=1", "-c", sql)
	cmd.Env = append(os.Environ(), "PGPASSWORD="+suPass, "PGCONNECT_TIMEOUT=10")
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: createNoWindow}
	out, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("provisionamento: %v\n%s", err, out)
	}

	if err := writeEnvFile(cfg, map[string]string{
		"GEBAN_PG_USER":     pgUser,
		"GEBAN_PG_PASSWORD": appPass,
	}); err != nil {
		return err
	}
	logf("banco %s/%s pronto", pgDB, pgUser)
	return nil
}

// writeEnvFile grava geban.env mesclando as chaves informadas.
func writeEnvFile(cfg *config, kv map[string]string) error {
	vals := map[string]string{
		"GEBAN_PG_HOST":     "127.0.0.1",
		"GEBAN_PG_PORT":     pgPort,
		"GEBAN_PG_DB":       pgDB,
		"GEBAN_PG_USER":     pgUser,
		"GEBAN_PG_PASSWORD": "",
		"GEBAN_PG_PASS":     "",
	}
	for _, ln := range readEnvFile(cfg.EnvFile) {
		if k, v, ok := strings.Cut(ln, "="); ok {
			vals[k] = v
		}
	}
	for k, v := range kv {
		vals[k] = v
	}
	var b strings.Builder
	for _, k := range []string{"GEBAN_PG_HOST", "GEBAN_PG_PORT", "GEBAN_PG_DB",
		"GEBAN_PG_USER", "GEBAN_PG_PASSWORD", "GEBAN_PG_PASS"} {
		fmt.Fprintf(&b, "%s=%s\n", k, vals[k])
	}
	return os.WriteFile(cfg.EnvFile, []byte(b.String()), 0600)
}

// ---------- Processos GEBAN ----------

func childEnv(cfg *config) []string {
	env := os.Environ()
	for _, kv := range readEnvFile(cfg.EnvFile) {
		k, v, ok := strings.Cut(kv, "=")
		if ok && strings.HasPrefix(k, "GEBAN_") && k != "GEBAN_PG_PASS" {
			env = append(env, k+"="+v)
		}
	}
	return env
}

func startChildren(cfg *config) error {
	advplc := filepath.Join(cfg.Dir, "advplc.exe")
	for _, p := range []struct{ name, entry string }{
		{"geban-ui", "src\\GEBTUI.prw"},
		{"geban-api", "src\\GEBWEB.prw"},
	} {
		args := []string{"serve", p.entry, "--port", "8081"}
		if p.name == "geban-api" {
			args = []string{"run", p.entry}
		}
		cmd := exec.Command(advplc, args...)
		cmd.Dir = cfg.Dir
		cmd.Env = childEnv(cfg)
		cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: createNoWindow}
		logPath := filepath.Join(cfg.DataDir, p.name+".log")
		if lf, err := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644); err == nil {
			cmd.Stdout, cmd.Stderr = lf, lf
		}
		if err := cmd.Start(); err != nil {
			return fmt.Errorf("%s: %w", p.name, err)
		}
		children = append(children, cmd)
		logf("%s iniciado (pid %d, log %s)", p.name, cmd.Process.Pid, logPath)
	}
	return nil
}

// ---------- Scheduler (GEBSCHJOB a cada minuto) ----------

func ensureScheduler(cfg *config) error {
	// schtasks não propaga variáveis de ambiente — por isso um .cmd
	// carrega geban.env antes de chamar o advplc.
	cmdFile := filepath.Join(cfg.Dir, "geban-scheduler.cmd")
	advplc := filepath.Join(cfg.Dir, "advplc.exe")
	schedLog := filepath.Join(cfg.DataDir, "scheduler.log")
	body := "@echo off\r\n" +
		"for /f \"usebackq tokens=1,* delims==\" %%a in (\"" + cfg.EnvFile + "\") do set \"%%a=%%b\"\r\n" +
		"cd /d \"" + cfg.Dir + "\"\r\n" +
		"\"" + advplc + "\" run src\\GEBSCHJOB.prw >> \"" + schedLog + "\" 2>&1\r\n"
	if err := os.WriteFile(cmdFile, []byte(body), 0644); err != nil {
		return err
	}
	out, err := exec.Command("schtasks", "/Create", "/TN", "GEBAN Scheduler",
		"/SC", "MINUTE", "/MO", "1", "/TR", "\""+cmdFile+"\"",
		"/F", "/RL", "LIMITED").CombinedOutput()
	if err != nil {
		return fmt.Errorf("schtasks: %v — %s", err, out)
	}
	logf("tarefa 'GEBAN Scheduler' registrada (1/min)")
	return nil
}

// ---------- util ----------

func openBrowserWhenReady() {
	for i := 0; i < 60; i++ {
		if c, err := net.DialTimeout("tcp", "127.0.0.1:8081", time.Second); err == nil {
			c.Close()
			exec.Command("rundll32", "url.dll,FileProtocolHandler", "http://127.0.0.1:8081").Start()
			return
		}
		time.Sleep(time.Second)
	}
}

func runCmd(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: createNoWindow}
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func randomPassword() (string, error) {
	b := make([]byte, 18)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func readEnvFile(path string) []string {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	return strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n")
}

func readEnvValue(path, key string) string {
	for _, ln := range readEnvFile(path) {
		if k, v, ok := strings.Cut(ln, "="); ok && k == key {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

func logf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "[geban-launcher %s] %s\n",
		time.Now().Format("15:04:05"), fmt.Sprintf(format, args...))
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "GEBAN: "+format+"\n", args...)
	os.Exit(1)
}
