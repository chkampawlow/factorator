ALTER TABLE erp_document_number_sequences
    ADD CONSTRAINT chk_document_sequence_type CHECK (document_type IN ('FACTURE','DEVIS','AVOIR','BON_COMMANDE','BON_LIVRAISON','BON_SORTIE')),
    ADD CONSTRAINT chk_document_sequence_year CHECK (document_year BETWEEN 2000 AND 2200),
    ADD CONSTRAINT chk_document_sequence_number CHECK (next_number > 0);

