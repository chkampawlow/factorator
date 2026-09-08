<?php
declare(strict_types=1);
ini_set('display_errors','0'); ini_set('log_errors','1'); error_reporting(E_ALL);
header('Content-Type: application/json');
require_once __DIR__.'/../config/db.php';
require_once __DIR__.'/../config/response.php';
require_once __DIR__.'/../config/rate_limit.php';
require_once __DIR__.'/../config/audit.php';
require_once __DIR__.'/password_policy.php';

try {
    if (($_SERVER['REQUEST_METHOD']??'GET')!=='POST') jsonResponse(['success'=>false,'message'=>'Use POST'],405);
    $data=json_decode(file_get_contents('php://input'),true);
    if(!is_array($data)) throw new DomainException('Invalid request.');
    $email=strtolower(trim((string)($data['email']??'')));
    $code=trim((string)($data['code']??''));
    $password=(string)($data['password']??'');
    if(filter_var($email,FILTER_VALIDATE_EMAIL)===false) throw new DomainException('A valid email is required.');
    if(!preg_match('/^\d{6}$/',$code)) throw new DomainException('Enter the six-digit reset code.');
    enforceRateLimit('reset_password',$email,10,15*60);
    assertStrongPassword($password,[$email]);

    $conn=db(); $conn->begin_transaction();
    $stmt=$conn->prepare("SELECT t.id,t.user_id,t.token_hash,t.expires_at,t.attempts FROM user_tokens t JOIN users u ON u.id=t.user_id WHERE u.email=? AND t.type='password_reset' ORDER BY t.id DESC LIMIT 1 FOR UPDATE");
    $stmt->bind_param('s',$email); $stmt->execute(); $token=$stmt->get_result()->fetch_assoc(); $stmt->close();
    $valid=$token&&(int)$token['attempts']<5&&strtotime((string)$token['expires_at'])>=time()&&hash_equals((string)$token['token_hash'],hash('sha256',$code));
    if(!$valid){
        if($token){$increment=$conn->prepare('UPDATE user_tokens SET attempts=attempts+1 WHERE id=?');$tokenId=(int)$token['id'];$increment->bind_param('i',$tokenId);$increment->execute();$increment->close();}
        $conn->commit(); throw new DomainException('The reset code is invalid or expired.');
    }

    $userId=(int)$token['user_id']; $newHash=password_hash($password,PASSWORD_DEFAULT);
    $update=$conn->prepare('UPDATE users SET password_hash=? WHERE id=?');$update->bind_param('si',$newHash,$userId);$update->execute();$update->close();
    $delete=$conn->prepare("DELETE FROM user_tokens WHERE user_id=? AND type='password_reset'");$delete->bind_param('i',$userId);$delete->execute();$delete->close();
    $revoke=$conn->prepare('UPDATE auth_refresh_tokens SET revoked_at=COALESCE(revoked_at,NOW()) WHERE user_id=?');$revoke->bind_param('i',$userId);$revoke->execute();$revoke->close();
    $conn->commit(); clearRateLimit('reset_password',$email);
    try{auditLog($conn,null,$userId,'AUTH.PASSWORD_RESET','USER',$userId,null,[],'AUTH');}catch(Throwable $ignored){}
    jsonResponse(['success'=>true,'message'=>'Password updated.']);
} catch(InvalidArgumentException|DomainException $e){
    if(isset($conn)&&$conn instanceof mysqli){try{$conn->rollback();}catch(Throwable $ignored){}}
    jsonResponse(['success'=>false,'message'=>$e->getMessage()],400);
} catch(Throwable $e){
    if(isset($conn)&&$conn instanceof mysqli){try{$conn->rollback();}catch(Throwable $ignored){}}
    structuredLog('ERROR','AUTH.PASSWORD_RESET_ERROR',['exception'=>get_class($e),'message'=>$e->getMessage()]);
    jsonResponse(['success'=>false,'message'=>'Unable to reset the password right now.'],500);
}
