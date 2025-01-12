pub const CommandAdressingError = error{
    NoCommandProvided,
    UnknownCommand,
};

pub const CommandArgsError = error{
    InvalidArgumentCount,
};
