<?php

declare(strict_types=1);

const NEW_USER_APPROVAL_SETTING = 'new_user_approval_required';

function platformSettingsTableExists(mysqli $conn): bool
{
    $statement = $conn->prepare("SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='erp_platform_settings' LIMIT 1");
    $statement->execute();
    $exists = (bool)$statement->get_result()->fetch_row();
    $statement->close();
    return $exists;
}

function platformBooleanSetting(mysqli $conn, string $key, bool $default): bool
{
    if (!platformSettingsTableExists($conn)) return $default;

    $statement = $conn->prepare('SELECT setting_value FROM erp_platform_settings WHERE setting_key=? LIMIT 1');
    $statement->bind_param('s', $key);
    $statement->execute();
    $row = $statement->get_result()->fetch_assoc();
    $statement->close();
    if (!$row) return $default;

    $value = strtolower(trim((string)$row['setting_value']));
    if (in_array($value, ['1', 'true', 'yes', 'on'], true)) return true;
    if (in_array($value, ['0', 'false', 'no', 'off'], true)) return false;
    return $default;
}

