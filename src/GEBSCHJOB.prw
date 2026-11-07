#include "totvs.ch"
#include "GEBSCH.prw"

/*/{Protheus.doc} GEBSCHJOB
    Executor do agendador. Chamado a cada minuto pelo timer (advplc run src/GEBSCHJOB.prw).
    Percorre as empresas provisionadas e roda o que estiver devido (src/GEBSCH.prw).
    @type Executor
    @since 07/11/2026
/*/
User Function GEBSCHJOB()
    Local nRodou := 0
    // Conecta no PostgreSQL antes de qualquer consulta (sem isso o runtime usa SQLite).
    If !GEBDBConecta()
        ConOut("GEBSCHJOB: falha ao conectar no banco")
        Return .F.
    EndIf
    nRodou := GEBSCHALL()
    ConOut("GEBSCHJOB: rotinas executadas=" + cValToChar(nRodou))
Return .T.
