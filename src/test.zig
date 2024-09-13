const std = @import("std");
const zoop = @import("zoop.zig");
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();
var p: ?*Sub = null;
var i: ?IHuman = null;
pub fn main() !void {
    const s = try zoop.new(allocator, Sub, null);
    p = s;
    i = zoop.cast(s, IHuman);
    const all = .{
        zoopicall(),
        zoopasclass(),
        zoopasiface(),
        zoopcastclass(),
        zoopcastiface(),
    };
    var l = all.len;
    if (l > 0) {
        l = 0;
    }
}

fn zoopicall() @TypeOf(zoop.icall(i.?, "getName", .{})) {
    return zoop.icall(i.?, "getName", .{});
}
fn zoopasclass() @TypeOf(zoop.as(p.?, Human)) {
    return zoop.as(p.?, Human);
}
fn zoopasiface() @TypeOf(zoop.as(p.?, IHuman)) {
    return zoop.as(p.?, IHuman);
}
fn zoopcastiface() @TypeOf(zoop.cast(p.?, IHuman)) {
    return zoop.cast(p.?, IHuman);
}
fn zoopcastclass() @TypeOf(zoop.cast(p.?, Human)) {
    return zoop.cast(p.?, Human);
}

pub const IHuman = struct {
    ptr: *anyopaque,
    vptr: *anyopaque,

    pub fn getName(self: IHuman) []const u8 {
        return zoop.icall(self, "getName", .{});
        // return zoop.vptr(self).getName(zoop.cptr(self));
    }

    pub fn setName(self: IHuman, name: []const u8) void {
        zoop.icall(self, "setName", .{name});
        // zoop.vptr(self).setName(zoop.cptr(self), name);
    }
};

pub const Human = struct {
    age: u8 align(zoop.alignment) = 99,
    name: []const u8 = "default",

    pub fn init(self: *Human, name: []const u8) void {
        self.name = name;
    }

    pub fn deinit(self: *Human) void {
        self.name = "";
    }

    pub fn getName(self: *const Human) []const u8 {
        return self.name;
    }

    pub fn setName(self: *Human, name: []const u8) void {
        self.name = name;
    }
};

pub const Sub = struct {
    pub const extends = .{IHuman};
    // 'super' can be other name, but align must be zoop.alignment
    super: Human align(zoop.alignment),
    age: u65 = 99,

    pub fn init(self: *Sub, name: []const u8) void {
        self.super.init(name);
    }
};

pub const SubSub = struct {
    super: Sub align(zoop.alignment),

    pub fn init(self: *SubSub, name: []const u8) void {
        self.super.init(name);
    }
};

pub const Custom = struct {
    super: SubSub align(zoop.alignment),
    age: u16 = 99,
    pub fn init(self: *Custom, name: []const u8) void {
        self.super.init(name);
    }

    // override
    pub fn getName(_: *Custom) []const u8 {
        return "custom";
    }
};
test "zoop" {
    const t = std.testing;

    if (true) {
        var human = zoop.make(Human, null);
        try t.expect(zoop.as(&human.class, IHuman) == null);

        // test inherit
        var sub = zoop.make(Sub, .{ .super = .{ .name = "sub" } });
        const psub = &sub.class;
        const phuman: *Human = &sub.class.super;
        const ksub = zoop.Klass(Sub).from(psub);
        const khuman = zoop.Klass(Human).from(phuman);
        try t.expect(@intFromPtr(ksub) == @intFromPtr(khuman));
        try t.expectEqualStrings(phuman.getName(), "sub");

        const phuman2 = &sub.class.super;
        try t.expect(@intFromPtr(psub) == @intFromPtr(phuman2));
        var ihuman = zoop.cast(&sub.class, IHuman);
        try t.expect(@intFromPtr(&sub.class) == @intFromPtr(&sub.class.super));
        try t.expectEqualStrings(ihuman.getName(), "sub");
        ihuman = zoop.cast(&sub, IHuman);
        try t.expectEqualStrings(ihuman.getName(), "sub");
        ihuman.setName("sub2");
        try t.expectEqualStrings(ihuman.getName(), "sub2");
        try t.expectEqualStrings(sub.class.super.getName(), "sub2");

        // test classInfo
        try t.expect(zoop.classInfo(ihuman) == zoop.classInfo(&sub));
        try t.expect(zoop.classInfo(ihuman) == zoop.classInfo(&sub.class));
        try t.expect(zoop.classInfo(&sub) == zoop.classInfo(&sub.class));

        // test typeinfo
        try t.expect(zoop.typeInfo(ihuman) != zoop.typeInfo(sub));
        try t.expect(zoop.typeInfo(ihuman) == zoop.typeInfo(IHuman));

        // test deep inherit
        var subsub = zoop.make(SubSub, null);
        subsub.class.init("subsub");
        ihuman = zoop.cast(&subsub.class, IHuman);
        try t.expectEqualStrings(ihuman.getName(), "subsub");
        ihuman = zoop.cast(&subsub, IHuman);
        try t.expectEqualStrings(ihuman.getName(), "subsub");

        // test override and as()
        var custom = zoop.make(Custom, null);
        custom.class.init("sub");
        try t.expect(zoop.isRootPtr(&custom));
        try t.expect(zoop.isRootPtr(&custom.class));
        try t.expect(!zoop.isRootPtr(&custom.class.super));
        try t.expect(!zoop.isRootPtr(zoop.Klass(Sub).from(&custom.class.super.super)));
        try t.expectEqualStrings(custom.class.super.super.super.getName(), "sub");
        try t.expectEqualStrings(zoop.cast(&custom, Human).name, "sub");
        try t.expectEqualStrings(zoop.cast(&custom.class, Human).name, "sub");
        try t.expectEqualStrings(zoop.as(&custom, Human).?.name, "sub");
        try t.expectEqualStrings(zoop.as(&custom.class, Human).?.name, "sub");
        try t.expectEqualStrings(zoop.getField(&custom, "name", []const u8).*, "sub");
        ihuman = zoop.as(zoop.as(&custom, zoop.IObject).?, IHuman).?;
        try t.expectEqualStrings(ihuman.getName(), "custom");

        // test deinit()
        zoop.destroy(&human);
        try t.expect(human.class.getName().len == 0);
        zoop.destroy(&sub);
        try t.expect(sub.class.super.getName().len == 0);
        zoop.destroy(&custom.class);
        try t.expect(custom.class.super.super.super.name.len == 0);

        // test default field value
        custom = zoop.make(Custom, null);
        try t.expect(custom.class.age == 99);
        try t.expectEqualStrings(custom.class.super.super.super.name, "default");
        try t.expect(zoop.getAllocator(&custom) == null);

        // test mem
        var psubsub = try zoop.new(t.allocator, SubSub, null);
        try t.expect(zoop.getAllocator(psubsub) != null);
        try t.expect(zoop.getAllocator(zoop.cast(psubsub, zoop.IObject)) != null);
        zoop.destroy(zoop.cast(psubsub, zoop.IObject));
        psubsub = try zoop.new(t.allocator, SubSub, null);
        zoop.destroy(psubsub);
        psubsub = try zoop.new(t.allocator, SubSub, null);
        zoop.destroy(zoop.cast(psubsub, Human));
    }
}
