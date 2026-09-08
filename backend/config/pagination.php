<?php
function paginationInput(array $query): array { $page=max(1,(int)($query['page']??1));$size=min(100,max(1,(int)($query['page_size']??20)));return [$page,$size,($page-1)*$size]; }
function paginationSort(array $query,array $allowed,string $fallback): string { $key=(string)($query['sort']??$fallback);$direction=strtolower((string)($query['direction']??'desc'))==='asc'?'ASC':'DESC';return ($allowed[$key]??$allowed[$fallback]).' '.$direction; }
function paginatedResponse(array $data,int $page,int $size,int $total,array $aggregates=[]):void{jsonResponse(['success'=>true,'data'=>$data,'page'=>$page,'page_size'=>$size,'total'=>$total,'aggregates'=>(object)$aggregates]);}
