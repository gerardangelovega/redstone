const assert = @import("assert");

/// `Object` is the basic unit of storage in the main in-memory key-value store and is
/// mainly used to retrieve the parent container to access the actual data.
const Object = @This();

kind: Kind,

pub const Kind = enum(u8) {
    string,
};

pub const String = struct {
    object: Object,
    string: []const u8,

    /// Retrieve `String` instance from a `Object` pointer whose dereferenced value is
    /// owned by a `String` instance.
    pub fn from(object: *Object) *String {
        assert.cheap(object.kind == .string);

        return @fieldParentPtr("object", object);
    }
};
