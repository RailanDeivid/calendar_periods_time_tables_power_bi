/*
    Script para dimensão calendário completa em M
    Autor: Alison Pezzott 
    Atualizado em:  sábado, 14 de setembro de 2024 às 05:48
    Comunidade no Discord: https://comunidade.fluentebi.com        
*/

//********Configurações********

    let 
    //Especifique a data inicial 
    dataInicial = #date(2024, 1, 1), 

    //Especifique a data final. Padrão: Final do ano atual 
    dataFinal = Date.EndOfYear ( Date.From ( DateTime.LocalNow ( ) ) ), 
    
    //Especifique a data atual. Padrão: Data atual do servidor 
    dataAtual = Date.From ( DateTime.LocalNow ( ) ), 

    //Especifique o início da semana. Padrão: Day.Monday (Segunda-feira) 
    inicioSemana = Day.Monday, 

    //Especifique o mês do início do ano fiscal. Padrão: 4 (Abril)
    mesInicioAnoFiscal = 4, 

    /*Dia de início do mês de fechamento. 
        Padrão: 16 (siginifica que o mês de fechamento vai de 16 do mês corrente 
        até o dia 15 do próximo mês */
    diaInicioMesFechamento = 16, 

    //Especifique o idioma. Padrão: pt-BR (Português do Brasil)
    idioma = "pt-BR", 

    //Geração da tabela
    dCalendario = let

    //Lista com todas as datas 
    datasRange = List.Buffer ( 
        List.Transform ( 
            { Number.From ( dataInicial ) .. Number.From ( dataFinal ) }, 
            Date.From 
        ) 
    ), 

    //Lista com todos os anos 
    anosRange = List.Buffer ( 
        { Date.Year ( dataInicial ) .. Date.Year ( dataFinal )} 
    ), 

    //Feriados fixos que ocorrem em todos os anos 
    feriadosFixosCadastro = #table ( 
        type table [ 
            Dia = Int64.Type, 
            Mes = Int64.Type, 
            Feriado = text 
        ],
        {
          // Dia, Mês, Feriado
            { 01, 01, "Confraternização Universal"   }, 
            { 25, 01, "Aniversário da Cidade"        }, 
            { 21, 04, "Tiradentes"                   }, 
            { 01, 05, "Dia do Trabalhador"           }, 
            { 09, 07, "Revolução Constitucionalista" }, 
            { 07, 09, "Independência do Brasil"      }, 
            { 12, 10, "N. Srª Aparecida"             }, 
            { 02, 11, "Finados"                      }, 
            { 15, 11, "Proclamação da República"     }, 
            { 20, 11, "Consciência Negra"            }, 
            { 24, 12, "Véspera de Natal"             }, 
            { 25, 12, "Natal"                        }, 
            { 31, 12, "Véspera de Ano Novo"          } 
        } 
    ), 

    //Função que gera os feriados fixos para todos os anos 
    fxGeraFeriadosFixos = ( ano ) => 
        Table.AddColumn ( 
            feriadosFixosCadastro, 
            "Data", 
            each #date ( ano, [Mes], [Dia] ), 
            type date 
        ) 
        [ [Data], [Feriado] ], 

    //Gera a tabela de feriados fixos 
    feriadosFixos = Table.Combine ( 
        List.Transform ( 
            anosRange, 
            fxGeraFeriadosFixos 
        ) 
    ), 

    //Função que gera os feriados móveis 
    fxGeraFeriadosMoveis = ( ano ) => 
        let 
            modExcel =  ( x, y ) => let m = Number.Mod ( x, y ) in if  m < 0 then m + y else m, 
            pascoa =  Date.From ( 
                Number.Round ( 
                    Number.From ( #date ( ano, 4, 1 ) ) / 7 
                    +  modExcel ( 19 * modExcel ( ano, 19 ) - 7, 30 ) * 0.14, 
                    0, 
                    RoundingMode.Up 
                ) 
                * 7 - 6 
            ), 
            feriadosMoveis =  #table ( 
                type table [ 
                    Data = date, 
                    Feriado = text 
                ], 
                { 
                    { Date.AddDays(pascoa, -48 ), "Segunda-feira de Carnaval"  }, 
                    { Date.AddDays(pascoa, -47 ), "Terça-feira de Carnaval"    }, 
                    { Date.AddDays(pascoa, -46 ), "Quarta-feira de Cinzas"     }, 
                    { Date.AddDays(pascoa, -2  ), "Sexta-Feira Santa"          }, 
                    { pascoa                    , "Páscoa"                     }, 
                    { Date.AddDays(pascoa, 60  ), "Corpus Christi"             } 
                } 
            ) 
        in 
            feriadosMoveis, 

    //Gera a tabela de feriados móveis 
    feriadosMoveis = Table.Combine ( 
        List.Transform ( 
            anosRange, 
            fxGeraFeriadosMoveis 
        ) 
    ),  

    //Tabela contendo todos os feriados 
    feriados = Table.Combine ( 
        { feriadosFixos, feriadosMoveis } 
    ), 

    //Define a função de transformação de cada data 
    fxLinhaCalendario = ( data ) => 
        let 
        //Transformações de simples passada para reutilização
            zws = Character.FromNumber ( 8203 ), //Caracter invisível (zero-width spacing )
            dataOffset = Number.From ( data - dataAtual ), 
            ano = Date.Year ( data ), 
            mes = Date.Month ( data ), 
            trimestre = Date.QuarterOfYear ( data ), 
            anoInicial = Date.Year ( dataInicial ), 
            anoAtual = Date.Year ( dataAtual ), 
            anoFinal = Date.Year ( dataFinal ), 
            anoOffset = ano - anoAtual, 
            mesInicial = Date.Month ( dataInicial ), 
            mesAtual = Date.Month ( dataAtual ), 
            trimestreInicial = Date.QuarterOfYear ( dataInicial ), 
            trimestreAtual = Date.QuarterOfYear ( dataAtual ), 
            diaSemana = Date.DayOfWeek ( data, inicioSemana ) + 1, 
            diaSemanaIndiceZws = Text.Repeat ( zws, 7 - diaSemana ), 
            semanaDoAnoIsoNo = 
                let 
                    quintaNaSemana = Date.AddDays ( data, 3 - Date.DayOfWeek ( data, Day.Monday ) ), 
                    inicioAnoQuintaNaSemana = #date ( Date.Year ( quintaNaSemana ), 1, 1 ), 
                    difDias = Duration.Days ( quintaNaSemana - inicioAnoQuintaNaSemana ) 
                in 
                    Number.IntegerDivide ( difDias, 7, 0 ) + 1, 
            semanaDoAnoNum = Date.WeekOfYear ( data, inicioSemana ), 
            diaSemanaNome = Text.Proper ( Date.DayOfWeekName ( data, idioma ) ), 
            mesNome = Text.Proper ( Date.MonthName ( data, idioma ) ), 
            mesIndiceZws = Text.Repeat ( zws, 12 - mes ), 
            mesAnoIndice = 12 * ( ano - anoInicial ) + mes, 
            inicioMes = Date.StartOfMonth ( data ),
            fimMes = Date.EndOfMonth ( data ),
            diaMes = Date.Day ( data ), 
            mesOffset =  ( ( ano * 12 ) - 1 + mes ) - ( ( anoAtual * 12 ) - 1 + mesAtual ), 
            trimestreOffset = ( ( ano * 4 ) - 1 + trimestre ) - ( ( anoAtual * 4 ) - 1 + trimestreAtual ), 
            trimestreAno = "T" & Text.From ( trimestre ) & "/" & Text.From ( ano ), 
            anoIso = Date.Year ( Date.AddDays ( data, 26 - semanaDoAnoIsoNo ) ), 
            inicioSemanaIsoLinha = Date.StartOfWeek ( data, Day.Monday ), 
            fimSemanaIsoLinha = Date.EndOfWeek ( data, Day.Monday ), 
            inicioSemanaLinha = Date.StartOfWeek ( data, inicioSemana ), 
            fimSemanaLinha = Date.EndOfWeek ( data, inicioSemana ), 
            inicioSemanaIsoInicial = Date.StartOfWeek ( data, Day.Monday ), 
            inicioSemanaInicial = Date.StartOfWeek ( dataInicial, inicioSemana ), 
            inicioSemanaIsoAtual = Date.StartOfWeek ( dataAtual, Day.Monday ),
            inicioSemanaAtual = Date.StartOfWeek ( dataAtual, inicioSemana ), 
            semanaIsoOffset = Number.From ( inicioSemanaIsoLinha - inicioSemanaIsoAtual ) / 7,
            semanaOffset = Number.From ( inicioSemanaLinha - inicioSemanaAtual ) / 7, 
            semanaAnoIso = "S" & Text.PadStart ( Text.From ( semanaDoAnoIsoNo ), 2, "0" ) & "/" & Text.From ( anoIso ), 
            semanaAno = "S" & Text.PadStart ( Text.From ( semanaDoAnoNum ), 2, "0" ) & "/" & Text.From ( ano ), 
            semanaDoMes = 
                let 
                    inicioMes = Date.StartOfMonth ( Date.StartOfWeek ( data,inicioSemana ) ), 
                    primeirosSeteDias = List.Dates ( inicioMes, 7, #duration ( 1, 0, 0, 0 ) ), 
                    primeiroDia = List.Select ( primeirosSeteDias, each Date.DayOfWeek ( _, inicioSemana ) = 0 ) { 0 } 
                in 
                    Number.RoundUp ( Duration.Days ( data-primeiroDia ) / 7 + 0.05 ), 
            anoSemanal = Date.Year ( inicioSemanaLinha ), 
            mesSemanal = Date.Month ( inicioSemanaLinha ) , 
            mesSemanalNome = Text.Proper ( Date.MonthName ( inicioSemanaLinha, idioma ) ), 
            mesSemanalNomeAbrev = Text.Start ( mesSemanalNome, 3 ), 
            semanaDoMesPadraoNum = Date.WeekOfMonth ( data, inicioSemana ), 
            quinzenaDoMesNo = if Date.Day ( data ) <= 15 then 1 else 2, 
            quinzenaDoMesNoAtual = if Date.Day ( dataAtual ) <= 15 then 1 else 2, 
            mesAno = Text.Proper ( Date.ToText ( data, [ Format="MMM/yy", Culture =idioma ] ) ), 
            quinzenaMesAno = "Qui " & Text.From ( quinzenaDoMesNo ) & " - " & mesAno, 
            quinzenaIndice = 24 * ( ano - anoInicial ) + 2 * ( mes - mesInicial ) + quinzenaDoMesNo, 
            quinzenaIndiceAtual = 24 *  ( anoAtual - anoInicial ) + 2 * ( mesAtual - mesInicial ) + quinzenaDoMesNoAtual, 
            quinzenaOffset = quinzenaIndice - quinzenaIndiceAtual, 
            semestreNo = if mes <= 6 then 1 else 2, 
            semestreNoAtual = if mesAtual <= 6 then 1 else 2, 
            semestreIndice = ( 2 * ( ano - anoInicial ) ) + semestreNo, 
            semestreIndiceAtual = ( 2 * ( anoAtual - anoInicial ) ) + semestreNoAtual, 
            semestreOffset = semestreIndice - semestreIndiceAtual, 
            semestreAno = "S" & Text.From ( semestreNo ) & " - " & Text.From ( ano ), 
            bimestreNo = Number.RoundUp ( mes / 2, 0 ), 
            bimestreNoAtual = Number.RoundUp ( mesAtual / 2, 0 ), 
            bimestreAno = "B" & Text.From ( bimestreNo ) & " - " & Text.From ( ano ), 
            bimestreIndice = ( 6 * ( ano - anoInicial ) ) + bimestreNo, 
            bimestreIndiceAtual = ( 6 * ( anoAtual - anoInicial ) ) + bimestreNoAtual, 
            bimestreOffset = bimestreIndice - bimestreIndiceAtual, 
            feriado = try feriados{[ Data = data ]}[Feriado] otherwise null, 
            diaUtilNo = if feriado <> null 
                or List.Contains ( 
                    { 6 .. 7 }, 
                    Date.DayOfWeek ( data, Day.Monday ) + 1 
                ) 
                then 0 
                else 1, 
            mesDiaNo = Date.Month ( data ) * 100 + Date.Day ( data ), 
            estacaoAnoNo = 
                if mesDiaNo >= 321 and mesDiaNo <= 620 then 1 else 
                if mesDiaNo >= 621 and mesDiaNo <= 921 then 2 else 
                if mesDiaNo >= 922 and mesDiaNo <= 1221 then 3 else 
                4 ,
            dataReferenciaFechamento = if diaMes <= diaInicioMesFechamento - 1 then data else Date.AddMonths ( data, 1 )  

        in 
        //Saída das transformações 
        { 
            //DataIndice 
            Number.From ( data - dataInicial ) + 1, 

            //Data 
            data, 

            //DataOffset 
            dataOffset, 

            //DataNomeAtual 
            if dataOffset = 0 then "Data Atual" 
                else if dataOffset = -1 then "Data Anterior" 
                else if dataOffset = 1 then "Próxima Data" 
                else Date.ToText ( data, "dd/MM/yyyy" ), 

            //AnoNum 
            ano, 

            //AnoInicio 
            Date.StartOfYear ( data ), 

            //AnoFim 
            Date.EndOfYear ( data ), 

            //AnoIndice 
            ano - anoInicial + 1, 

            //AnoDecrescenteNome 
            ano, 

            //AnoDescrescenteNum 
            ano * -1, 

            //AnoFiscal 
            if mes >= mesInicioAnoFiscal then ano else ano - 1, 

            //AnoOffset 
            anoOffset, 

            //AnoNomeAtual 
            if anoOffset = 0 then "Ano Atual" 
                else if anoOffset = -1 then "Ano Anterior" 
                else if anoOffset = 1 then "Próximo Ano" 
                else Date.ToText ( data, "yyyy" ),

            //DiaDoMesNum 
            diaMes, 

            //DiaDoAnoNum 
            Date.DayOfYear ( data ), 

            //DiaDaSemanaNum 
            diaSemana, 

            //DiaDaSemanaNome 
            diaSemanaNome, 

            //DiaDaSemanaNomeAbrev 
            Text.Start ( diaSemanaNome, 3 ), 

            //DiaDaSemanaNomeIniciais 
            diaSemanaIndiceZws & Text.Start ( diaSemanaNome, 1 ), 

            //MesNum 
            mes, 

            //MesNome 
            mesNome, 

            //MesNomeAbrev 
            Text.Start ( mesNome, 3 ), 

            //MesNomeIniciais 
            mesIndiceZws & Text.Start ( mesNome, 1 ), 

            //MesAnoNum 
            ano * 100 + mes, 

            //MesAnoMome 
            mesAno, 

            //MesDiaNum 
            mes * 100 + diaMes, 

            //MesDiaNome
            Text.Proper ( Date.ToText ( data, [Format="MMM/dd", Culture =idioma] )), 

            //MesInicio 
            Date.StartOfMonth ( data ), 

            //MesFim 
            Date.EndOfMonth ( data ), 
            
            //MesIndice 
            mesAnoIndice, 
            
            //MesOffset 
            mesOffset, 
            
            //MesNomeAtual 
            if mesOffset = 0 then "Mês Atual" 
                else if mesOffset = -1 then "Mês Anterior" 
                else if mesOffset = 1 then "Próximo Mês" 
                else mesNome, 

            //MesNomeAbrevAtual 
            if mesOffset = 0 then "Mês Atual" 
                else if mesOffset = -1 then "Mês Anterior" 
                else if mesOffset = 1 then "Próximo Mês" 
                else Text.Start ( mesNome, 3 ), 
            
            //MesAnoNomeAtual 
            if mesOffset = 0 then "Mês Atual" 
                else if mesOffset = -1 then "Mês Anterior" 
                else if mesOffset = 1 then "Próximo Mês" 
                else mesAno, 
            
            //TrimestreNum 
            trimestre, 

            //TrimestreInicio 
            Date.StartOfQuarter ( data ), 

            //TrimestreFinal 
            Date.EndOfQuarter ( data ), 

            //TrimestreAnoNum
            ano * 100 + trimestre, 

            //TrimestreAnoNome 
            trimestreAno, 

            //TrimestreIndice 
            4 * ( ano - anoInicial ) + trimestre, 

            //TrimestreOffset 
            trimestreOffset, 

            //TrimestreAnoNomeAtual 
            if trimestreOffset = 0 then "Trimestre Atual" 
                else if trimestreOffset = -1 then "Trimestre Anterior" 
                else if trimestreOffset = 1 then "Próximo Trimestre" 
                else trimestreAno, 

            //SemanaIsoNum 
            semanaDoAnoIsoNo, 

            //AnoIsoNum 
            anoIso, 

            //SemanaIsoAnoNum 
            anoIso * 100 + semanaDoAnoIsoNo, 

            //SemanaIsoAnoNome 
            semanaAnoIso, 

            //SemanaIsoInicio 
            inicioSemanaIsoLinha, 

            //SemanaIsoFim 
            fimSemanaIsoLinha, 

            //SemanaIsoIndice 
            Number.From ( inicioSemanaIsoLinha - inicioSemanaIsoInicial ) / 7 + 1, 

            //SemanaIsoOffset 
            semanaOffset, 

            //SemanaIsoAnoNomeAtual 
            if semanaIsoOffset = 0 then "Semana Atual" 
                else if semanaIsoOffset = -1 then "Semana Anterior" 
                else if semanaIsoOffset = 1 then "Próxima Semana" 
                else semanaAnoIso, 

            //SemanaNo 
            semanaDoAnoNum, 

            //SemanaAnoNum 
            ano * 100 + semanaDoAnoNum, 

            //SemanaAnoNome 
            semanaAno, 

            //SemanaInicio 
            inicioSemanaLinha, 

            //SemanaFim 
            fimSemanaLinha, 

            //SemanaPeriodo
            Date.ToText ( inicioSemanaLinha, "dd/MM/yyyy" ) & " a " & Date.ToText ( fimSemanaLinha, "dd/MM/yyyy" ),

            //SemanaIndice 
            Number.From ( inicioSemanaLinha - inicioSemanaInicial ) / 7 + 1, 

            //SemanaOffset
            semanaOffset, 

            //SemanaAnoNomeAtual 
            if semanaOffset = 0 then "Semana Atual" 
                else if semanaOffset = -1 then "Semana Anterior" 
                else if semanaOffset = 1 then "Próxima Semana" 
                else semanaAno, 

            //SemanaDoMesNum 
            semanaDoMes, 

            //AnoSemanalNum 
            anoSemanal, 

            //MesSemanalNum 
            mesSemanal, 

            //MesSemanalNome 
            mesSemanalNome, 

            //MesSemanalNomeAbrev 
            mesSemanalNomeAbrev, 

            //MesAnoSemanalNum 
            anoSemanal * 100 + mesSemanal, 

            //MesAnoSemanalNome 
            Text.Proper ( Date.ToText ( inicioSemanaLinha, [ Format="MMM/yy", Culture=idioma ] )), 

            //SemanaDoMesPadraoNum
            semanaDoMesPadraoNum,

            //SemanaDoMesAnoPadraoNome
            mesAno & " " & Text.From ( semanaDoMesPadraoNum ),

            //SemanaDoMesAnoPadraoNum
            ano * 10000 + mes * 100 + semanaDoMesPadraoNum,

            //QuinzenaDoMesNum 
            quinzenaDoMesNo, 

            //QuinzenaMesNum 
            mes * 10 + quinzenaDoMesNo, 

            //QuinzenaMesNome 
            "Qui " & Text.From ( quinzenaDoMesNo ) & " - " & mesNome, 
            
            //QuinzenaMesAnoNum 
            ano * 10000 + mes * 100 + quinzenaDoMesNo, 

            //QuinzenaMesAnoNome 
            quinzenaMesAno, 

            //QuinzenaPeriodo
            let 
                inicioQuinzena = if quinzenaDoMesNo = 1 then inicioMes else Date.AddDays ( inicioMes, 15  ),
                fimQuinzena = if quinzenaDoMesNo = 2 then fimMes else Date.AddDays ( inicioMes, 14 )
            in
                Date.ToText ( inicioQuinzena, "dd/MM/yyyy" ) & " a " & Date.ToText ( fimQuinzena, "dd/MM/yyyy" ),

            //QuinzenaIndice
            quinzenaIndice,

            //QuinzenaOffset 
            quinzenaOffset, 

            //QuinzenaMesAnoNomeAtual 
            if quinzenaOffset = 0 then "Quinzena Atual" 
                else if quinzenaOffset = -1 then "Quinzena Anterior" 
                else if quinzenaOffset = 1 then "Próxima Quinzena" 
                else quinzenaMesAno, 

            //SemestreDoAnoNum 
            semestreNo, 

            //SemestreAnoNum 
            ano * 100 + semestreNo, 

            //SemestreAnoNome
            "S" & Text.From ( semestreNo ) & " - " & Text.From ( ano ), 

            //SemestreIndice 
            semestreIndice, 

            //Semestre Offset 
            semestreOffset, 

            //SemestreAnoNomeAtual 
            if semestreOffset = 0 then "Semestre Atual" 
                else if semestreOffset = -1 then "Semestre Anterior" 
                else if semestreOffset = 1 then "Próximo Semestre" 
                else semestreAno, 
            
            //BimestreDoAnoNum 
            bimestreNo, 

            //BimestreAnoNum 
            ano * 100 + bimestreNo, 

            //BimestreAnoNome 
            bimestreAno, 

            //BimestreIndice 
            bimestreIndice, 

            //BimestrOffset 
            bimestreOffset, 

            //BimestreAnoNomeAtual 
            if bimestreOffset = 0 then "Bimestre Atual" 
                else if bimestreOffset = -1 then "Bimestre Anterior" 
                else if bimestreOffset = 1 then "Próximo Bimestre" 
                else bimestreAno, 

            //FeriadoNome 
            feriado, 

            //DiaUtilNum 
            diaUtilNo, 

            //DiaUtilNome 
            if diaUtilNo = 0 then "Dia Não Útil" else "Dia Útil", 
            
            //EstacaoAnoNum 
            estacaoAnoNo, 

            //EstacaoAnoNome 
            if estacaoAnoNo = 1 then "Outono" 
                else if estacaoAnoNo = 2 then "Inverno" 
                else if estacaoAnoNo = 3 then "Primavera" 
                else "Verão",

            //MesFechamentoNum
            Date.Month ( dataReferenciaFechamento ),

            //MesFechamentoNome
            Text.Proper ( Date.ToText ( dataReferenciaFechamento, [ Format = "MMMM", Culture = idioma ] ) ),

            //MesFechamentoNomeAbrev
            Text.Proper ( Date.ToText ( dataReferenciaFechamento, [ Format = "MMM", Culture = idioma ] ) ),

            //AnoFechamentoNum
            Date.Year ( dataReferenciaFechamento ),

            //MesAnoFechamentoNum
            Date.Year ( dataReferenciaFechamento ) * 100 + Date.Month ( dataReferenciaFechamento ),

            //MesAnoFechamentoNome
            Text.Proper ( Date.ToText ( dataReferenciaFechamento, [ Format = "MMM/yy", Culture = idioma ] ) ),

            //DataFutura
            dataOffset > 0

        }, 

    //Gera a tabela calendário 
    calendario = #table ( 

        //Nomes e tipos das colunas 
        type table [ 
            DataIndice = Int64.Type, 
            Data = date, 
            DataOffset = Int64.Type, 
            DataNomeAtual = text, 
            AnoNum = Int64.Type, 
            AnoInicio = date, 
            AnoFim = date, 
            AnoIndice = Int64.Type, 
            AnoDecrescenteNome = Int64.Type, 
            AnoDecrescenteNum = Int64.Type, 
            AnoFiscal = Int64.Type, 
            AnoOffset = Int64.Type, 
            AnoNomeAtual = text, 
            DiaDoMesNum = Int64.Type, 
            DiaDoAnoNum = Int64.Type, 
            DiaDaSemanaNum = Int64.Type, 
            DiaDaSemanaNome = text, 
            DiaDaSemanaNomeAbrev = text, 
            DiaDaSemanaNomeIniciais = text,
            MesNum = Int64.Type, 
            MesNome = text, 
            MesNomeAbrev = text, 
            MesNomeIniciais = text, 
            MesAnoNum = Int64.Type, 
            MesAnoNome = text, 
            MesDiaNum = Int64.Type, 
            MesDiaNome = text, 
            MesInicio = date, 
            MesFim = date, 
            MesIndice = Int64.Type, 
            MesOffset = Int64.Type, 
            MesNomeAtual = text, 
            MesNomeAbrevAtual = text, 
            MesAnoNomeAtual = text, 
            TrimestreNum = Int64.Type, 
            TrimestreInicio = date, 
            TrimestreFim = date, 
            TrimestreAnoNum = Int64.Type,
            TrimestreAnoNome = text, 
            TrimestreIndice = Int64.Type, 
            TrimestreOffset = Int64.Type, 
            TrimestreAnoNomeAtual = text, 
            SemanaIsoNum = Int64.Type,
            AnoIsoNum = Int64.Type, 
            SemanaIsoAnoNum = Int64.Type, 
            SemanaIsoAnoNome = text, 
            SemanaIsoInicio = date, 
            SemanaIsoFim = date, 
            SemanaIsoIndice = Int64.Type, 
            SemanaIsoOffset = Int64.Type, 
            SemanaIsoAnoNomeAtual = text, 
            SemanaNum = Int64.Type, 
            SemanaAnoNum = Int64.Type, 
            SemanaAnoNome = text, 
            SemanaInicio = date, 
            SemanaFim = date, 
            SemanaPeriodo = text,
            SemanaIndice = Int64.Type, 
            SemanaOffset = Int64.Type, 
            SemanaAnoNomeAtual = text, 
            SemanaDoMesNum = Int64.Type, 
            AnoSemanalNum = Int64.Type, 
            MesSemanalNum = Int64.Type, 
            MesSemanalNome = text, 
            MesSemanalNomeAbrev = text, 
            MesAnoSemanalNum = Int64.Type, 
            MesAnoSemanalNome = text, 
            SemanaDoMesPadraoNum = Int64.Type,
            SemanaDoMesAnoPadraoNome = text, 
            SemanaDoMesAnoPadraoNum = Int64.Type, 
            QuinzenaDoMesNum = Int64.Type,
            QuinzenaMesNum = Int64.Type, 
            QuinzenaMesNome = text, 
            QuinzenaMesAnoNum = Int64.Type, 
            QuinzenaMesAnoNome = text, 
            QuinzenaPeriodo = text,
            QuinzenaIndice = Int64.Type, 
            QuinzenaOffset = Int64.Type, 
            QuinzenaMesAnoNomeAtual = text, 
            SemestreDoAnoNum = Int64.Type, 
            SemestreAnoNum = Int64.Type, 
            SemestreAnoNome = text, 
            SemestreIndice = Int64.Type, 
            SemestreOffset = Int64.Type, 
            SemestreAnoNomeAtual = text,
            BimestreDoAnoNum = Int64.Type, 
            BimestreAnoNum = Int64.Type, 
            BimestreAnoNome = text, 
            BimestreIndice = Int64.Type, 
            BimestreOffset = Int64.Type, 
            BimestreAnoNomeAtual = text, 
            FeriadoNome = text, 
            DiaUtilNum = Int64.Type, 
            DiaUtilNome = text, 
            EstacaoAnoNum = Int64.Type, 
            EstacaoAnoNome = text, 
            MesFechamentoNum = Int64.Type,
            MesFechamentoNome = text, 
            MesFechamentoNomeAbrev = text, 
            AnoFechamentoNum = Int64.Type,
            MesAnoFechamentoNum = Int64.Type,
            MesAnoFechamentoNome = text,
            DataFutura = Logical.Type 
        ], 

        //Invoca função de transformação 
        List.Transform ( datasRange, fxLinhaCalendario ) 
    ),
    
    // Adiciona o número do dia útil do mês
    adDiaUtilMes = 
    let
        tabela = Table.Buffer ( 
            Table.SelectColumns ( 
                calendario, 
                { "DiaDoMesNum", "MesIndice", "DiaUtilNum" } 
            ) 
        ), 

        addDiaUtilMes = Table.AddColumn (
            tabela, 
            "DiaUtilDoMes", 
            each let 
                __mesIndice = [MesIndice], 
                __DiaDoMes = [DiaDoMesNum] 
            in 
                List.Sum ( 
                    Table.SelectRows ( 
                        tabela, 
                        each [MesIndice] = __mesIndice  
                            and [DiaDoMesNum] <= __DiaDoMes 
                    )
                    [DiaUtilNum]
                ), 
            Int64.Type
        )[ [MesIndice], [DiaDoMesNum], [DiaUtilDoMes] ], 

        join = Table.Join (
            calendario, { "MesIndice", "DiaDoMesNum" },
            addDiaUtilMes, { "MesIndice", "DiaDoMesNum" }
        ) 
    in
        join 
            
in
    adDiaUtilMes 

in dCalendario 

    //Fim