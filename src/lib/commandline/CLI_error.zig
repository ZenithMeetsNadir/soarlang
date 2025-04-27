pub const CommandAdressingError = error{
    NoCommandProvided,
    UnknownCommand,
};

pub const CommandExecutionError = error{
    InvalidArgumentCount,
    ExecutionFailed,
    ExecutionInterrupted,
};
