/// Vaultly 核心领域层
///
/// **零 Flutter 依赖**：这里只放与平台无关的正确性逻辑——加密原语、
/// 条目模型、字段级加密策略、合并与墓碑规则、备份负载格式。
/// App、桌面宿主（P6 daemon）与 CLI 都必须走这一份实现，
/// 任何一方私改规则（如 merge 的 LWW 细节）都会造成多端行为分叉。
///
/// 边界（ADR-006 R4）：
/// - 允许：dart:io / dart:convert / dart:typed_data、纯 Dart 三方包
/// - 禁止：package:flutter/*、flutter_riverpod、flutter_secure_storage 等
///   平台通道依赖——那是 data/presentation 层的事
library;

// ==================== 加密 ====================
export 'src/crypto/crypto_service.dart';

// ==================== 异常（跨层契约） ====================
export 'src/exceptions/app_exception.dart';

// ==================== 条目模型 ====================
export 'src/vault/vault_entry.dart';
export 'src/vault/entry_codec.dart';
export 'src/vault/vault_tombstone.dart';

// ==================== 字段级加密策略 ====================
export 'src/vault/encryption/entry_encryption_strategy.dart';
export 'src/vault/encryption/field_based_encryption_strategy.dart';
export 'src/vault/encryption/login_encryption_strategy.dart';
export 'src/vault/encryption/bank_card_encryption_strategy.dart';
export 'src/vault/encryption/secure_note_encryption_strategy.dart';
export 'src/vault/encryption/identity_encryption_strategy.dart';

// ==================== 搜索 ====================
export 'src/vault/search/entry_search_strategy.dart';

// ==================== 同步规则 ====================
export 'src/sync/vault_merge.dart';
export 'src/sync/backup_payload.dart';
