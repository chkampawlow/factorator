<?php
function operationalAccountingResult(mysqli $conn,int $userId,int $year):array{
    $from="$year-01-01";$to="$year-12-31";
    $s=$conn->prepare("SELECT ROUND(COALESCE(SUM(CASE WHEN invoice_type='AVOIR' THEN -ABS(subtotal_tnd) ELSE subtotal_tnd END),0),3) revenue FROM erp_invoices WHERE user_id=? AND invoice_date BETWEEN ? AND ? AND invoice_type IN('FACTURE','AVOIR') AND is_validated=1");$s->bind_param('iss',$userId,$from,$to);$s->execute();$revenue=(float)$s->get_result()->fetch_assoc()['revenue'];$s->close();
    $s=$conn->prepare("SELECT ROUND(COALESCE(SUM(cogs_value),0),3) cogs FROM product_stock_movements WHERE user_id=? AND created_at>=? AND created_at<DATE_ADD(?,INTERVAL 1 DAY)");$s->bind_param('iss',$userId,$from,$to);$s->execute();$cogs=(float)$s->get_result()->fetch_assoc()['cogs'];$s->close();
    $s=$conn->prepare("SELECT ROUND(COALESCE(SUM(amount),0),3) expenses FROM expense_notes WHERE user_id=? AND expense_date BETWEEN ? AND ? AND status IN('APPROVED','REIMBURSED')");$s->bind_param('iss',$userId,$from,$to);$s->execute();$expenses=(float)$s->get_result()->fetch_assoc()['expenses'];$s->close();
    return['revenue'=>$revenue,'cogs'=>$cogs,'expenses'=>$expenses,'result'=>round($revenue-$cogs-$expenses,3)];
}
