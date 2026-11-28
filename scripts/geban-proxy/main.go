// geban-proxy — reverse proxy same-origin do ambiente de demonstracao GEBAN.
//
// Expõe um unico ponto de entrada (padrao :8081) que divide o trafego:
//
//	/pdv, /pdv/*, /api/*  -> GEBWEB (PDV web + API REST, :8090)
//	demais caminhos       -> advplc serve GEBTUI (ERP TUI PO-UI, :8082)
//
// Com tudo na mesma origem, o FWOPENTAB("/pdv#tok=...") do menu "Frente de
// loja" abre o PDV na mesma porta do ERP — sem segunda credencial (o token
// da sessao viaja no fragmento) e com WebSocket /pdv/ws funcionando
// (httputil.ReverseProxy faz hijack do upgrade).
//
// Uso: geban-proxy [-listen :8081] [-erp http://127.0.0.1:8082] [-web http://127.0.0.1:8090]
package main

import (
	"flag"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
)

func proxyTo(target string) *httputil.ReverseProxy {
	u, err := url.Parse(target)
	if err != nil {
		log.Fatalf("alvo invalido %q: %v", target, err)
	}
	p := httputil.NewSingleHostReverseProxy(u)
	p.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("proxy %s -> %s: %v", r.URL.Path, target, err)
		http.Error(w, "backend indisponivel", http.StatusBadGateway)
	}
	return p
}

func main() {
	listen := flag.String("listen", ":8081", "endereco de escuta do proxy")
	erp := flag.String("erp", "http://127.0.0.1:8082", "backend do ERP (advplc serve GEBTUI)")
	web := flag.String("web", "http://127.0.0.1:8090", "backend do PDV/API (advplc run GEBWEB)")
	flag.Parse()

	pERP := proxyTo(*erp)
	pWEB := proxyTo(*web)

	mux := http.NewServeMux()
	// PDV e API sao do GEBWEB; todo o resto e' do ERP.
	for _, prefix := range []string{"/pdv", "/pdv/", "/api/"} {
		mux.Handle(prefix, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			pWEB.ServeHTTP(w, r)
		}))
	}
	mux.Handle("/", pERP)

	log.Printf("geban-proxy escutando em %s (erp=%s web=%s)", *listen, *erp, *web)
	log.Fatal(http.ListenAndServe(*listen, mux))
}

