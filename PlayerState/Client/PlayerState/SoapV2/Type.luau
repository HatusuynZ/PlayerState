local Module = {}

export type SoapObject = {
    Add: (self: any, ...any) -> (),
    Remove: (self: any, ...any) -> (),
    Cleanup: (self: any) -> (),
    Destroy: (self: any) -> (),
}

return Module