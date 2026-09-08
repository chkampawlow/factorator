<?php

declare(strict_types=1);

/**
 * Reserve the next tenant-scoped reference atomically.
 *
 * The sequence row is locked until commit, preventing two simultaneous creates
 * from receiving the same reference. References are never reused after delete.
 */
function nextEntityReference(mysqli $conn, int $userId, string $entityType): string
{
    $prefixes = ['CLIENT' => 'C', 'SUPPLIER' => 'F'];
    $entityType = strtoupper(trim($entityType));
    if ($userId <= 0 || !isset($prefixes[$entityType])) {
        throw new InvalidArgumentException('Invalid entity reference request.');
    }

    $conn->begin_transaction();

    try {
        $insert = $conn->prepare(
            'INSERT IGNORE INTO erp_entity_reference_sequences (user_id, entity_type, next_number) VALUES (?, ?, 1)'
        );
        $insert->bind_param('is', $userId, $entityType);
        $insert->execute();
        $insert->close();

        $select = $conn->prepare(
            'SELECT next_number FROM erp_entity_reference_sequences WHERE user_id = ? AND entity_type = ? FOR UPDATE'
        );
        $select->bind_param('is', $userId, $entityType);
        $select->execute();
        $row = $select->get_result()->fetch_assoc();
        $select->close();
        if (!$row) {
            throw new RuntimeException('Could not reserve an entity reference.');
        }

        $number = (int)$row['next_number'];
        $update = $conn->prepare(
            'UPDATE erp_entity_reference_sequences SET next_number = ? WHERE user_id = ? AND entity_type = ?'
        );
        $nextNumber = $number + 1;
        $update->bind_param('iis', $nextNumber, $userId, $entityType);
        $update->execute();
        $update->close();

        $conn->commit();

        return $prefixes[$entityType] . str_pad((string)$number, 6, '0', STR_PAD_LEFT);
    } catch (Throwable $error) {
        $conn->rollback();
        throw $error;
    }
}
