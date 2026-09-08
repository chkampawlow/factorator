<?php

if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require_once __DIR__ . '/../config/env.php';
loadEnv(__DIR__ . '/../.env');
require_once __DIR__ . '/../config/logger.php';
set_exception_handler(static function(Throwable $e):void{
    structuredLog('CRITICAL','BACKUP.FAILED',['exception'=>get_class($e),'message'=>$e->getMessage()]);
    fwrite(STDERR,'Backup failed; request_id='.(function_exists('appRequestId')?appRequestId():'CLI').PHP_EOL);exit(1);
});

function backupOption(string $name, ?string $default=null): ?string {
    global $argv;
    foreach ($argv as $arg) if (str_starts_with($arg,"--$name=")) return substr($arg,strlen($name)+3);
    return $default;
}
function runBackupCommand(array $command, array $environment=[]): void {
    $pipes=[];$process=proc_open($command,[0=>['file','/dev/null','r'],1=>['pipe','w'],2=>['pipe','w']],$pipes,null,array_merge($_ENV,$environment));
    if(!is_resource($process)) throw new RuntimeException('Could not start backup command');
    $stdout=stream_get_contents($pipes[1]);$stderr=stream_get_contents($pipes[2]);fclose($pipes[1]);fclose($pipes[2]);
    $code=proc_close($process);if($code!==0)throw new RuntimeException('Backup command failed: '.trim($stderr ?: $stdout));
}
function removeBackupTree(string $path): void {
    if(!is_dir($path)||!preg_match('/\/el-fatoura-(daily|weekly)-\d{8}T\d{6}Z-[a-f0-9]{8}$/',$path))return;
    $iterator=new RecursiveIteratorIterator(new RecursiveDirectoryIterator($path,FilesystemIterator::SKIP_DOTS),RecursiveIteratorIterator::CHILD_FIRST);
    foreach($iterator as $item){$item->isDir()?rmdir($item->getPathname()):unlink($item->getPathname());}rmdir($path);
}

$key=(string)($_ENV['BACKUP_ENCRYPTION_KEY']??getenv('BACKUP_ENCRYPTION_KEY')?:'');
if(strlen($key)<32)throw new RuntimeException('BACKUP_ENCRYPTION_KEY must contain at least 32 characters');
$tier=strtolower((string)backupOption('tier','daily'));
if(!in_array($tier,['daily','weekly'],true))throw new RuntimeException('Tier must be daily or weekly');
$outputRoot=rtrim((string)backupOption('output-dir',$_ENV['BACKUP_OUTPUT_DIR']??dirname(__DIR__).'/storage/backups'),'/');
if($outputRoot===''||$outputRoot==='/')throw new RuntimeException('Unsafe backup output directory');
if(!is_dir($outputRoot)&&!mkdir($outputRoot,0700,true)&&!is_dir($outputRoot))throw new RuntimeException('Could not create backup output directory');
$stamp=gmdate('Ymd\THis\Z').'-'.bin2hex(random_bytes(4));
$backupDir=$outputRoot.'/el-fatoura-'.$tier.'-'.$stamp;
if(!mkdir($backupDir,0700))throw new RuntimeException('Could not create backup directory');
$dump=$backupDir.'/database.sql';$tar=$backupDir.'/attachments.tar';
$dumpEncrypted=$dump.'.enc';$tarEncrypted=$tar.'.enc';
$attachments=(string)backupOption('attachments-dir',dirname(__DIR__).'/storage/accounting');

try {
    $dumpCommand=['/Applications/XAMPP/bin/mysqldump','--host='.(string)$_ENV['DB_HOST'],'--port='.(string)($_ENV['DB_PORT']??3306),
        '--user='.(string)$_ENV['DB_USER'],'--single-transaction','--quick','--triggers','--hex-blob',
        '--result-file='.$dump,(string)$_ENV['DB_NAME']];
    runBackupCommand($dumpCommand,['MYSQL_PWD'=>(string)$_ENV['DB_PASS']]);chmod($dump,0600);
    if(is_dir($attachments))runBackupCommand(['/usr/bin/tar','-cf',$tar,'-C',$attachments,'.']);
    else runBackupCommand(['/usr/bin/tar','-cf',$tar,'--files-from','/dev/null']);
    chmod($tar,0600);
    foreach([[$dump,$dumpEncrypted],[$tar,$tarEncrypted]] as [$plain,$encrypted]){
        runBackupCommand(['/usr/bin/openssl','enc','-aes-256-cbc','-pbkdf2','-iter','200000','-salt','-in',$plain,'-out',$encrypted,'-pass','env:BACKUP_ENCRYPTION_KEY'],['BACKUP_ENCRYPTION_KEY'=>$key]);
        chmod($encrypted,0600);unlink($plain);
    }
    $conn=new mysqli((string)$_ENV['DB_HOST'],(string)$_ENV['DB_USER'],(string)$_ENV['DB_PASS'],(string)$_ENV['DB_NAME'],(int)($_ENV['DB_PORT']??3306));
    $counts=[];foreach(['users','erp_invoices','products','product_stock_movements','app_audit_log'] as $table)$counts[$table]=(int)$conn->query("SELECT COUNT(*) FROM `$table`")->fetch_row()[0];
    $migration=$conn->query('SELECT version FROM schema_migrations ORDER BY applied_at DESC,version DESC LIMIT 1')->fetch_row()[0]??null;$conn->close();
    $manifest=['format'=>'EL_FATOURA_BACKUP_V1','created_at'=>gmdate(DATE_ATOM),'tier'=>$tier,'database'=>(string)$_ENV['DB_NAME'],
        'schema_version'=>$migration,'artifacts'=>['database.sql.enc'=>['sha256'=>hash_file('sha256',$dumpEncrypted),'bytes'=>filesize($dumpEncrypted)],
        'attachments.tar.enc'=>['sha256'=>hash_file('sha256',$tarEncrypted),'bytes'=>filesize($tarEncrypted)]],'row_counts'=>$counts];
    $manifestJson=json_encode($manifest,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES);file_put_contents($backupDir.'/manifest.json',$manifestJson,LOCK_EX);
    file_put_contents($backupDir.'/manifest.hmac',hash_hmac('sha256',$manifestJson,$key).PHP_EOL,LOCK_EX);
    file_put_contents($backupDir.'/COMPLETE',gmdate(DATE_ATOM).PHP_EOL,LOCK_EX);
    chmod($backupDir.'/manifest.json',0600);chmod($backupDir.'/manifest.hmac',0600);chmod($backupDir.'/COMPLETE',0600);

    $offsite=rtrim((string)($_ENV['BACKUP_OFFSITE_DIR']??getenv('BACKUP_OFFSITE_DIR')?:''),'/');
    if($offsite!==''){if(!is_dir($offsite)&&!mkdir($offsite,0700,true)&&!is_dir($offsite))throw new RuntimeException('Could not create off-site directory');
        $destination=$offsite.'/'.basename($backupDir);if(!mkdir($destination,0700))throw new RuntimeException('Off-site backup already exists');
        foreach(glob($backupDir.'/*') as $file)if(!copy($file,$destination.'/'.basename($file)))throw new RuntimeException('Off-site copy failed');}

    if(backupOption('no-retention')===null){$keep=$tier==='daily'?(int)($_ENV['BACKUP_DAILY_RETENTION']??14):(int)($_ENV['BACKUP_WEEKLY_RETENTION']??8);
        $dirs=glob($outputRoot.'/el-fatoura-'.$tier.'-*',GLOB_ONLYDIR)?:[];rsort($dirs);foreach(array_slice($dirs,max(1,$keep)) as $old)removeBackupTree($old);}
    structuredLog('INFO','BACKUP.COMPLETED',['tier'=>$tier,'offsite_copied'=>$offsite!=='','artifact_count'=>2,'row_counts'=>$counts]);
    echo json_encode(['success'=>true,'backup_dir'=>$backupDir,'tier'=>$tier,'offsite_copied'=>$offsite!=='','manifest'=>$manifest],JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES).PHP_EOL;
}catch(Throwable $e){if(is_file($dump))unlink($dump);if(is_file($tar))unlink($tar);throw $e;}
