pub const Language = enum { soar_IR, soar_hlvl };
pub const ExecType = enum { script, dll };

language: Language = .soar_hlvl,
lang_version: []const u8 = "0.8.0",
exec_type: ExecType = .script,
