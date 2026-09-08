<?php

function ensureExpenseNotesSchema(mysqli $conn): void
{
    static $ensured = false;

    if ($ensured) {
        return;
    }

    $conn->query("SELECT supplier_id,source_document_type,source_document_id,source_document_number FROM expense_notes LIMIT 0");

    $ensured = true;
}
