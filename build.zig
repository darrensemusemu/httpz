const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    b.addModule(.{ .name = "httpz", .source_file = .{ .path = "src/main.zig" } });

    inline for (.{ "simple", "json", "html" }) |name| {
        const example = b.addExecutable(.{
            .name = name,
            .root_source_file = .{ .path = "examples/" ++ name ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });
        example.addAnonymousModule("httpz", .{ .source_file = .{ .path = "src/main.zig" } });
        example.install();

        const example_run_cmd = b.addRunArtifact(example);
        const example_step = b.step("run:" ++ name, "Run and serve example");
        example_step.dependOn(&example_run_cmd.step);
    }

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.emit_docs = .{ .emit_to = "docs/" };
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
