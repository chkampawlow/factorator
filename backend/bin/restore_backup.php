<?php

if(PHP_SAPI!=='cli'){http_response_code(404);exit;}
require_once __DIR__.'/../config/env.php';loadEnv(__DIR__.'/../.env');
function restoreArg(string $name):?string{global $argv;foreach($argv as $arg)if(str_starts_with($arg,"--$name="))return substr($arg,strlen($name)+3);return null;}
function restoreRun(array $command,array $env=[]):void{$pipes=[];$p=proc_open($command,[0=>['file','/dev/null','r'],1=>['pipe','w'],2=>['pipe','w']],$pipes,null,array_merge($_ENV,$env));if(!is_resource($p))throw new RuntimeException('Could not start restore command');$out=stream_get_contents($pipes[1]);$err=stream_get_contents($pipes[2]);fclose($pipes[1]);fclose($pipes[2]);$code=proc_close($p);if($code!==0)throw new RuntimeException('Restore command failed: '.trim($err?:$out));}
$backup=rtrim((string)restoreArg('backup'),'/');$target=(string)restoreArg('target-db');$attachmentTarget=(string)restoreArg('attachments-target');
if(!is_dir($backup)||!is_file($backup.'/COMPLETE'))throw new RuntimeException('A complete backup directory is required');
if(!preg_match('/^[A-Za-z0-9_]+_restore_test_[A-Za-z0-9_]+$/',$target))throw new RuntimeException('Target database must be an isolated *_restore_test_* database');
$key=(string)($_ENV['BACKUP_ENCRYPTION_KEY']??getenv('BACKUP_ENCRYPTION_KEY')?:'');if(strlen($key)<32)throw new RuntimeException('BACKUP_ENCRYPTION_KEY must contain at least 32 characters');
$manifestJson=(string)file_get_contents($backup.'/manifest.json');$expected=trim((string)file_get_contents($backup.'/manifest.hmac'));
if(!hash_equals($expected,hash_hmac('sha256',$manifestJson,$key)))throw new RuntimeException('Backup manifest signature is invalid');
$manifest=json_decode($manifestJson,true,512,JSON_THROW_ON_ERROR);foreach($manifest['artifacts'] as $name=>$info)if(!hash_equals($info['sha256'],hash_file('sha256',$backup.'/'.$name)))throw new RuntimeException("Checksum failed for $name");
$temp=sys_get_temp_dir().'/el-fatoura-restore-'.bin2hex(random_bytes(6));if(!mkdir($temp,0700))throw new RuntimeException('Could not create restore workspace');
$dump=$temp.'/database.sql';$tar=$temp.'/attachments.tar';
try{foreach([['database.sql.enc',$dump],['attachments.tar.enc',$tar]] as [$encrypted,$plain])restoreRun(['/usr/bin/openssl','enc','-d','-aes-256-cbc','-pbkdf2','-iter','200000','-in',$backup.'/'.$encrypted,'-out',$plain,'-pass','env:BACKUP_ENCRYPTION_KEY'],['BACKUP_ENCRYPTION_KEY'=>$key]);
    $host=(string)$_ENV['DB_HOST'];$port=(string)($_ENV['DB_PORT']??3306);
    $restoreUser=getenv('RESTORE_DB_USER');$restorePass=getenv('RESTORE_DB_PASS');
    $user=(string)($_ENV['RESTORE_DB_USER']??($restoreUser!==false?$restoreUser:$_ENV['DB_USER']));
    $pass=(string)($_ENV['RESTORE_DB_PASS']??($restorePass!==false?$restorePass:$_ENV['DB_PASS']));
    $admin=new mysqli($host,$user,$pass,'',(int)$port);$escaped=$admin->real_escape_string($target);if($admin->query("SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$escaped'")->num_rows)throw new RuntimeException('Restore target already exists');$admin->query("CREATE DATABASE `$target` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci");$admin->close();
    restoreRun(['/Applications/XAMPP/bin/mysql','--host='.$host,'--port='.$port,'--user='.$user,$target,'--execute=source '.$dump],['MYSQL_PWD'=>$pass]);
    if($attachmentTarget!==''){if(file_exists($attachmentTarget))throw new RuntimeException('Attachment restore target already exists');if(!mkdir($attachmentTarget,0700,true))throw new RuntimeException('Could not create attachment target');restoreRun(['/usr/bin/tar','-xf',$tar,'-C',$attachmentTarget]);}
    $check=new mysqli($host,$user,$pass,$target,(int)$port);$counts=[];foreach($manifest['row_counts'] as $table=>$expectedCount){$actual=(int)$check->query("SELECT COUNT(*) FROM `$table`")->fetch_row()[0];$counts[$table]=['expected'=>$expectedCount,'actual'=>$actual,'match'=>$actual===$expectedCount];}$check->close();$success=!in_array(false,array_column($counts,'match'),true);
    echo json_encode(['success'=>$success,'target_database'=>$target,'row_counts'=>$counts,'attachments_restored'=>$attachmentTarget!==''],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES).PHP_EOL;exit($success?0:1);
}finally{foreach([$dump,$tar] as $file)if(is_file($file))unlink($file);if(is_dir($temp))rmdir($temp);}
