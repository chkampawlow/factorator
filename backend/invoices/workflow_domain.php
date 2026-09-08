<?php
function workflowDevisStatuses():array{return ['DRAFT','SENT','ACCEPTED','REJECTED'];}
function workflowTransformationStatuses():array{return ['NOT_TRANSFORMED','PARTIALLY_ORDERED','FULLY_ORDERED'];}
function workflowInvoiceDraftStatuses():array{return ['DRAFT','UNPAID'];}
function workflowOrderStatuses():array{return ['DRAFT','CONFIRMED','PARTIALLY_DELIVERED','DELIVERED','CANCELLED','INVOICED'];}
function workflowDeliveryStatuses():array{return ['DRAFT','CONFIRMED','DELIVERED','CANCELLED'];}
function workflowRequireStatus(string $status,array $allowed,string $label='status'):string{$value=strtoupper(trim($status));if(!in_array($value,$allowed,true))throw new Exception('Invalid '.$label);return $value;}
