this is a string

/* generated by blx::xsd2sql */

drop table if exists ROOT_xml_1;
drop table if exists RichiestaOloRegolatorio;
drop table if exists m_RichiestaOloRegolatorio;
drop table if exists RichiestaOloRegolatorio_Richiesta;
drop table if exists RichiestaOloRegolatorio_Richiesta_Testata;
drop table if exists RichiestaOloRegolatorio_Richiesta_Testata_Correlazioni;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Attivazione;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaAttiva;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaAttiva_DatiSede;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_DatiCliente;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_DatiSede;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_POTS;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_POTS_Simplex;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_POTS_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_POTS_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_ISDN;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_ISDN_BRAMono;
drop table if exists ROR_R_Ordine_Attivazione_WLRLineaNonAttiva_ISDN_BRAMulti;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_ISDN_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_WLRLineaNonAttiva_ISDN_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva_POTS;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva_POTS_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva_POTS_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva_ISDN;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva_ISDN_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva_ISDN_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva_DestinazioneUso;
drop table if exists ROR_R_Ordine_Attivazione_ULLLineaAttiva_DestinazioneUso_dati;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttiva_FOB;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaNonAttiva;
drop table if exists ROR_R_Ordine_Attivazione_ULLLineaNonAttiva_DestinazioneUso;
drop table if exists ROR_R_Ordine_Attivazione_ULLLineaNonAttiva_DestinazioneUso_dati;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttivaNP;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttivaNP_POTS;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttivaNP_POTS_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttivaNP_POTS_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttivaNP_ISDN;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttivaNP_ISDN_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttivaNP_ISDN_PBX;
drop table if exists ROR_R_Ordine_Attivazione_ULLLineaAttivaNP_DestinazioneUso;
drop table if exists ROR_R_Ordine_Attivazione_ULLLineaAttivaNP_DestinazioneUso_dati;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLLineaAttivaNP_FOB;
drop table if exists ROR_R_Ordine_Attivazione_ULLLineaAttivaNP_FlagAggiuntivi;
drop table if exists ROR_R_O_A_ULLLineaAttivaNP_FlagAggiuntivi_NumerazioneAggiuntiva;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttiva;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttiva_POTS;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttiva_POTS_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttiva_POTS_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttiva_ISDN;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttiva_ISDN_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttiva_ISDN_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttiva_FOB;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttivaNP;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttivaNP_POTS;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttivaNP_POTS_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttivaNP_POTS_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttivaNP_ISDN;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttivaNP_ISDN_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttivaNP_ISDN_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaAttivaNP_FOB;
drop table if exists ROR_R_Ordine_Attivazione_ULLDatiLineaAttivaNP_FlagAggiuntivi;
drop table if exists ROR_R_O_A_ULLDLANP_FlagAggiuntivi_NumerazioneAggiuntiva;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ULLDatiLineaNonAttiva;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Attivazione_VULL;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Attivazione_VULL_POTS;
drop table if exists ROR_Richiesta_Ordine_Attivazione_VULL_POTS_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_VULL_POTS_PBX;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Attivazione_VULL_ISDN;
drop table if exists ROR_Richiesta_Ordine_Attivazione_VULL_ISDN_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_VULL_ISDN_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_VULL_NumerazioneAggiuntiva;
drop table if exists ROR_Richiesta_Ordine_Attivazione_SHASenzaManoDopera;
drop table if exists ROR_Richiesta_Ordine_Attivazione_SHAConManoDopera;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ProlungamentoAccesso;
drop table if exists ROR_Richiesta_Ordine_Attivazione_ProlungamentoAccesso_Referente;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Attivazione_CPS;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Attivazione_CPS_POTS;
drop table if exists ROR_Richiesta_Ordine_Attivazione_CPS_POTS_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_CPS_POTS_GNR;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Attivazione_CPS_ISDN;
drop table if exists ROR_Richiesta_Ordine_Attivazione_CPS_ISDN_BRA;
drop table if exists ROR_Richiesta_Ordine_Attivazione_CPS_ISDN_PBX;
drop table if exists ROR_Richiesta_Ordine_Attivazione_CPS_ISDN_GNR;
drop table if exists ROR_Richiesta_Ordine_Attivazione_CPS_DatiCliente;
drop table if exists ROR_Richiesta_Ordine_Attivazione_CPS_DatiSede;
drop table if exists ROR_Richiesta_Ordine_Attivazione_CPS_Referente;
drop table if exists ROR_Richiesta_Ordine_Attivazione_Colocazione;
drop table if exists ROR_Richiesta_Ordine_Attivazione_Colocazione_InternaCondivisa;
drop table if exists ROR_R_Ordine_Attivazione_Colocazione_InternaCondivisa_Referente;
drop table if exists ROR_Richiesta_Ordine_Attivazione_Colocazione_Esterna;
drop table if exists ROR_Richiesta_Ordine_Attivazione_Colocazione_Esterna_Referente;
drop table if exists ROR_Richiesta_Ordine_Attivazione_Colocazione_ImmediateVicinanze;
drop table if exists ROR_R_O_Attivazione_Colocazione_ImmediateVicinanze_Referente;
drop table if exists ROR_Richiesta_Ordine_Attivazione_Colocazione_InternaDedicata;
drop table if exists ROR_R_Ordine_Attivazione_Colocazione_InternaDedicata_Referente;
drop table if exists ROR_Richiesta_Ordine_Attivazione_Colocazione_InternaVirtuale;
drop table if exists ROR_R_Ordine_Attivazione_Colocazione_InternaVirtuale_Referente;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Variazione;
drop table if exists ROR_Richiesta_Ordine_Variazione_VariazioneWLR;
drop table if exists ROR_Richiesta_Ordine_Variazione_VariazioneWLR_AttivazioneSTS;
drop table if exists ROR_R_O_V_VariazioneWLR_AttivazioneSTS_CodiceSTSMultinumero;
drop table if exists ROR_R_O_V_VWLR_ASTS_CodiceSTSMultinumero_NumerazioneAggiuntiva;
drop table if exists ROR_Richiesta_Ordine_Variazione_VariazioneWLR_CessazioneSTS;
drop table if exists ROR_R_O_V_VariazioneWLR_CessazioneSTS_CodiceSTSMultinumero;
drop table if exists ROR_R_O_V_VWLR_CSTS_CodiceSTSMultinumero_NumerazioneAggiuntiva;
drop table if exists ROR_Richiesta_Ordine_Variazione_VariazioneWLR_PrestazioniWLR;
drop table if exists ROR_R_Ordine_Variazione_VariazioneWLR_PrestazioniWLR_Trasloco;
drop table if exists ROR_R_O_Variazione_VariazioneWLR_PrestazioniWLR_CambioCanali;
drop table if exists ROR_R_O_V_VariazioneWLR_PrestazioniWLR_CambioTipologiaAccesso;
drop table if exists ROR_Richiesta_Ordine_Variazione_VariazioneULL;
drop table if exists ROR_Richiesta_Ordine_Variazione_VariazioneULL_DestinazioneUso;
drop table if exists ROR_R_Ordine_Variazione_VariazioneULL_DestinazioneUso_dati;
drop table if exists ROR_R_Ordine_Variazione_VariazioneULL_CessSolaNPsuULL_NP;
drop table if exists ROR_R_Ordine_Variazione_VariazioneULL_CessSoloUllsuULL_NP;
drop table if exists ROR_R_Ordine_Variazione_VariazioneULL_TrasformazioneVull_Ull_NP;
drop table if exists ROR_R_O_V_VULL_TrasformazioneVull_Ull_NP_DestinazioneUso;
drop table if exists ROR_R_O_V_VULL_TrasformazioneVull_Ull_NP_DestinazioneUso_dati;
drop table if exists ROR_R_O_Variazione_VariazioneULL_TrasformazioneVull_Ull_NP_POTS;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_NP_POTS_GNR;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_NP_POTS_PBX;
drop table if exists ROR_R_O_Variazione_VariazioneULL_TrasformazioneVull_Ull_NP_ISDN;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_NP_ISDN_GNR;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_NP_ISDN_PBX;
drop table if exists ROR_R_Ordine_Variazione_VariazioneULL_TrasformazioneVull_Ull;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_DestinazioneUso;
drop table if exists ROR_R_O_V_VULL_TrasformazioneVull_Ull_DestinazioneUso_dati;
drop table if exists ROR_R_O_Variazione_VariazioneULL_TrasformazioneVull_Ull_POTS;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_POTS_GNR;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_POTS_PBX;
drop table if exists ROR_R_O_Variazione_VariazioneULL_TrasformazioneVull_Ull_ISDN;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_ISDN_GNR;
drop table if exists ROR_R_O_V_VariazioneULL_TrasformazioneVull_Ull_ISDN_PBX;
drop table if exists ROR_R_O_Variazione_VariazioneULL_TrasformazioneUllComm_UllLna;
drop table if exists ROR_R_O_V_VULL_TrasformazioneUllComm_UllLna_DestinazioneUso;
drop table if exists ROR_R_O_V_VULL_TUC_UllLna_DestinazioneUso_dati;
drop table if exists ROR_Richiesta_Ordine_Variazione_VariazioneULL_CambioCoppia;
drop table if exists ROR_Richiesta_Ordine_Variazione_VariazioneULL_Trasloco;
drop table if exists ROR_Richiesta_Ordine_Variazione_AmpliamentoPA;
drop table if exists ROR_Richiesta_Ordine_Variazione_AmpliamentoPA_Referente;
drop table if exists ROR_Richiesta_Ordine_Variazione_AmpliamentoColocazione;
drop table if exists ROR_R_Ordine_Variazione_AmpliamentoColocazione_InternaCondivisa;
drop table if exists ROR_R_O_V_AmpliamentoColocazione_InternaCondivisa_Referente;
drop table if exists ROR_Richiesta_Ordine_Variazione_AmpliamentoColocazione_Esterna;
drop table if exists ROR_R_O_Variazione_AmpliamentoColocazione_Esterna_Referente;
drop table if exists ROR_R_O_Variazione_AmpliamentoColocazione_ImmediateVicinanze;
drop table if exists ROR_R_O_V_AmpliamentoColocazione_ImmediateVicinanze_Referente;
drop table if exists ROR_R_Ordine_Variazione_AmpliamentoColocazione_InternaDedicata;
drop table if exists ROR_R_O_V_AmpliamentoColocazione_InternaDedicata_Referente;
drop table if exists ROR_R_Ordine_Variazione_AmpliamentoColocazione_InternaVirtuale;
drop table if exists ROR_R_O_V_AmpliamentoColocazione_InternaVirtuale_Referente;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Cessazione;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneWLRLineaAttiva;
drop table if exists ROR_R_Ordine_Cessazione_CessazioneWLRLineaAttiva_DatiSede;
drop table if exists ROR_R_Ordine_Cessazione_CessazioneWLRLineaAttiva_Rientro;
drop table if exists ROR_R_O_C_CessazioneWLRLineaAttiva_Rientro_RientroVeloce;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneWLRLineaNonAttiva;
drop table if exists ROR_R_Ordine_Cessazione_CessazioneWLRLineaNonAttiva_DatiSede;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL_ULL;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL_ULL_NP;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL_ULL_NP_Rientro;
drop table if exists ROR_R_O_Cessazione_CessazioneULL_ULL_NP_Rientro_RientroVeloce;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL_SharedAccess;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL_Vull;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL_Vull_Rientro;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL_ULLDati;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneULL_ULLDati_NP;
drop table if exists ROR_R_Ordine_Cessazione_CessazioneULL_ULLDati_NP_Rientro;
drop table if exists ROR_R_O_C_CessazioneULL_ULLDati_NP_Rientro_RientroVeloce;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazionePA;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazionePA_Referente;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneColocazione;
drop table if exists ROR_R_Ordine_Cessazione_CessazioneColocazione_InternaCondivisa;
drop table if exists ROR_R_O_C_CessazioneColocazione_InternaCondivisa_Referente;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneColocazione_Esterna;
drop table if exists ROR_R_Ordine_Cessazione_CessazioneColocazione_Esterna_Referente;
drop table if exists ROR_R_O_Cessazione_CessazioneColocazione_ImmediateVicinanze;
drop table if exists ROR_R_O_C_CessazioneColocazione_ImmediateVicinanze_Referente;
drop table if exists ROR_R_Ordine_Cessazione_CessazioneColocazione_InternaDedicata;
drop table if exists ROR_R_O_C_CessazioneColocazione_InternaDedicata_Referente;
drop table if exists ROR_R_Ordine_Cessazione_CessazioneColocazione_InternaVirtuale;
drop table if exists ROR_R_O_C_CessazioneColocazione_InternaVirtuale_Referente;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_POTS;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_POTS_PBX;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_POTS_GNR;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_ISDN;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_ISDN_BRA;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_ISDN_PBX;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_ISDN_GNR;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_DatiCliente;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_DatiSede;
drop table if exists ROR_Richiesta_Ordine_Cessazione_CessazioneCPS_Referente;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Migrazione;
drop table if exists RichiestaOloRegolatorio_Richiesta_Ordine_Migrazione_Servizio;
drop table if exists ROR_Richiesta_Ordine_Migrazione_Servizio_Ull;
drop table if exists ROR_Richiesta_Ordine_Migrazione_Servizio_Ull_DestinazioneUso;
drop table if exists ROR_R_Ordine_Migrazione_Servizio_Ull_DestinazioneUso_dati;
drop table if exists ROR_Richiesta_Ordine_Migrazione_Servizio_Ull_NP;
drop table if exists ROR_Richiesta_Ordine_Migrazione_Servizio_Ull_NP_DNaggiuntive;
drop table if exists ROR_Richiesta_Ordine_Migrazione_Servizio_UllDati;
drop table if exists ROR_Richiesta_Ordine_Migrazione_Servizio_UllDati_NP;
drop table if exists ROR_R_Ordine_Migrazione_Servizio_UllDati_NP_DNaggiuntive;
drop table if exists ROR_Richiesta_Ordine_Migrazione_Servizio_SharedAccess;
drop table if exists RichiestaOloRegolatorio_Richiesta_StatoAvanzamento;
drop table if exists RichiestaOloRegolatorio_Richiesta_CancellazioneAccodamento;
drop table if exists RichiestaOloRegolatorio_Richiesta_InterruzioneMigrazione;
drop table if exists RichiestaOloRegolatorio_Richiesta_Annullamento;
drop table if exists RichiestaOloRegolatorio_Richiesta_Comunicazione;
drop table if exists ROR_Richiesta_Comunicazione_RiscontroCodiceSessione;
drop table if exists ROR_R_Comunicazione_RiscontroCodiceSessione_RichiestaNok;
drop table if exists ROR_Richiesta_Comunicazione_AccettazioneOpereSpeciali;
drop table if exists ROR_Richiesta_Comunicazione_PrenotificaDisattivazioneCPS;
drop table if exists ROR_R_Comunicazione_PrenotificaDisattivazioneCPS_DatiCliente;
drop table if exists ROR_R_Comunicazione_PrenotificaDisattivazioneCPS_Rifiuto;
drop table if exists NotificaOloRegolatorio;
drop table if exists m_NotificaOloRegolatorio;
drop table if exists NotificaOloRegolatorio_NotificaTrasformazioneULL;
drop table if exists NOR_NotificaTrasformazioneULL_TestataNotifica;
drop table if exists NOR_NotificaTrasformazioneULL_CessazioneFonia;
drop table if exists NOR_NotificaTrasformazioneULL_CessazioneSHAperULL;
drop table if exists NOR_NotificaTrasformazioneULL_CessULL_NPperULL;
drop table if exists NOR_NTULL_CessULL_NPperULL_NumerazioneAggiuntiva;
drop table if exists NOR_NotificaTrasformazioneULL_CessULLD_NPperULLD;
drop table if exists NOR_NTULL_CessULLD_NPperULLD_NumerazioneAggiuntiva;
drop table if exists NotificaOloRegolatorio_NotificaULL;
drop table if exists NotificaOloRegolatorio_NotificaULL_Acquisizione;
drop table if exists NotificaOloRegolatorio_NotificaULL_Accettazione;
drop table if exists NOR_NotificaULL_Accettazione_NumerazioneAggiuntiva;
drop table if exists NotificaOloRegolatorio_NotificaULL_Espletamento;
drop table if exists NOR_NotificaULL_Espletamento_NumerazioneAggiuntiva;
drop table if exists NotificaOloRegolatorio_NotificaULL_StatoAvanzamento;
drop table if exists NOR_NotificaULL_StatoAvanzamento_NumerazioneAggiuntiva;
drop table if exists NotificaOloRegolatorio_NotificaULL_Sospensione;
drop table if exists NotificaOloRegolatorio_NotificaULL_RimodulazioneDac;
drop table if exists NotificaOloRegolatorio_NotificaULL_DataAppuntamento;
drop table if exists NotificaOloRegolatorio_NotificaULL_Accodamento;
drop table if exists NotificaOloRegolatorio_NotificaULL_RimodulazioneDPS;
drop table if exists NotificaOloRegolatorio_NotificaULL_InCaricoADelivery;
drop table if exists NotificaOloRegolatorio_NotificaULL_RagioneSocialeSU;
drop table if exists NotificaOloRegolatorio_NotificaWLR;
drop table if exists NotificaOloRegolatorio_NotificaWLR_Acquisizione;
drop table if exists NotificaOloRegolatorio_NotificaWLR_Accettazione;
drop table if exists NOR_NotificaWLR_Accettazione_NumerazioneAggiuntiva;
drop table if exists NotificaOloRegolatorio_NotificaWLR_Espletamento;
drop table if exists NOR_NotificaWLR_Espletamento_NumerazioneAggiuntiva;
drop table if exists NotificaOloRegolatorio_NotificaWLR_StatoAvanzamento;
drop table if exists NOR_NotificaWLR_StatoAvanzamento_NumerazioneAggiuntiva;
drop table if exists NotificaOloRegolatorio_NotificaWLR_CessazionePerNP;
drop table if exists NOR_NotificaWLR_CessazionePerNP_NumerazioneAggiuntiva;
drop table if exists NotificaOloRegolatorio_NotificaWLR_Sospensione;
drop table if exists NotificaOloRegolatorio_NotificaWLR_DataAppuntamento;
drop table if exists NotificaOloRegolatorio_NotificaWLR_PreventivoOpereSpeciali;
drop table if exists NOR_NotificaWLR_PreventivoOpereSpeciali_DescrizioneOpere;
drop table if exists NOR_NWLR_PreventivoOpereSpeciali_DescrizioneOpere_CircuitoAereo;
drop table if exists NOR_NWLR_POS_DescrizioneOpere_CircuitoInCavoSotterraneo;
drop table if exists NOR_NWLR_PreventivoOpereSpeciali_DescrizioneOpere_PonteRadio;
drop table if exists NOR_NotificaWLR_PreventivoOpereSpeciali_DescrizioneOpere_Altro;
drop table if exists NotificaOloRegolatorio_NotificaWLR_Accodamento;
drop table if exists NotificaOloRegolatorio_NotificaWLR_RimodulazioneDPS;
drop table if exists NotificaOloRegolatorio_NotificaWLR_InCaricoADelivery;
drop table if exists NotificaOloRegolatorio_NotificaWLR_RimodulazioneDac;
drop table if exists NotificaOloRegolatorio_NotificaWLR_Annullamento;
drop table if exists NotificaOloRegolatorio_NotificaCPS;
drop table if exists NotificaOloRegolatorio_NotificaCPS_EsitoVerifiche;
drop table if exists NotificaOloRegolatorio_NotificaCPS_EsitoValidazione;
drop table if exists NotificaOloRegolatorio_NotificaCPS_EsitoValidazione_Referente;
drop table if exists NotificaOloRegolatorio_NotificaCPS_EsitoEspletamento;
drop table if exists NotificaOloRegolatorio_NotificaCPS_StatoAvanzamento;
drop table if exists NotificaOloRegolatorio_NotificaCPS_PreAvvisoCessazione;
drop table if exists NOR_NotificaCPS_PreAvvisoCessazione_Referente;
drop table if exists NotificaOloRegolatorio_NotificaCPS_NotificaCessazione;
drop table if exists NotificaOloRegolatorio_NotificaCPS_NotificaCessazione_Referente;
drop table if exists NotificaOloRegolatorio_NotificaVsRecipient;
drop table if exists NotificaOloRegolatorio_NotificaVsRecipient_TestataNotifica;
drop table if exists NotificaOloRegolatorio_NotificaVsRecipient_Acquisizione;
drop table if exists NOR_NotificaVsRecipient_Acquisizione_RichiestaNok;
drop table if exists NotificaOloRegolatorio_NotificaVsRecipient_Accettazione;
drop table if exists NOR_NotificaVsRecipient_Accettazione_RichiestaNok;
drop table if exists NotificaOloRegolatorio_NotificaVsRecipient_Espletamento;
drop table if exists NOR_NotificaVsRecipient_Espletamento_RichiestaNok;
drop table if exists NotificaOloRegolatorio_NotificaVsRecipient_RimodulazioneDAC;
drop table if exists NotificaOloRegolatorio_NotificaVsRecipient_Annullamento;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating_TestataNotifica;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating_Accettazione;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating_Accettazione_NP;
drop table if exists NOR_NotificaVsDonorDonating_Accettazione_NP_DNaggiuntive;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating_Espletamento;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating_Espletamento_NP;
drop table if exists NOR_NotificaVsDonorDonating_Espletamento_NP_DNaggiuntive;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating_RimodulazioneDAC;
drop table if exists NOR_NotificaVsDonorDonating_RimodulazioneDAC_NP;
drop table if exists NOR_NotificaVsDonorDonating_RimodulazioneDAC_NP_DNaggiuntive;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating_Annullamento;
drop table if exists NotificaOloRegolatorio_NotificaVsDonorDonating_Annullamento_NP;
drop table if exists NOR_NotificaVsDonorDonating_Annullamento_NP_DNaggiuntive;
drop table if exists NOR_NotificaVsDonorDonating_CessazioneVsDonating;
drop table if exists NOR_NotificaVsDonorDonating_CessazioneVsDonating_NP;
drop table if exists NOR_NVDD_CessazioneVsDonating_NP_DNaggiuntive;
drop table if exists ProgrammazioneOlo;
drop table if exists m_ProgrammazioneOlo;
drop table if exists ProgrammazioneOlo_ProgrammazioneWLR;
drop table if exists ProgrammazioneOlo_ProgrammazioneCPS;
drop table if exists VerificaProgrammazioneOlo;
drop table if exists m_VerificaProgrammazioneOlo;
drop table if exists VerificaProgrammazioneOlo_VerificaFileProgrammazioneWLR;
drop table if exists VerificaProgrammazioneOlo_VerificaFileProgrammazioneCPS;
drop table if exists ExportVolumiAssegnatiOlo;
drop table if exists m_ExportVolumiAssegnatiOlo;
drop table if exists ExportVolumiAssegnatiOlo_ExportVolumiAssegnatiWLR;
drop table if exists ExportVolumiAssegnatiOlo_ExportVolumiAssegnatiCPS;
drop table if exists CodiceOrdine;
drop table if exists DataType;
drop table if exists ClienteFinale;
drop table if exists DatiSede;
drop table if exists Referente;
drop table if exists Rifiuto;
drop table if exists TestataNotifica;
drop table if exists TimeType;
drop table if exists Flag;
drop table if exists CodiceQualita;
drop table if exists Indicatore;
drop table if exists StatoOrdine;
drop table if exists TipoFonia;
drop table if exists TipoDati;
drop table if exists CodiceSTS;
drop table if exists FlagRientro;
drop table if exists RichiestaOk;
drop table if exists RichiestaNok;
drop table if exists ClassifOrdine;
drop table if exists DN;
drop table if exists FasciaOraria;

/* end of  blx::xsd2sql */

