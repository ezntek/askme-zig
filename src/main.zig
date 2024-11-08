// askme.zig: very quick zig thinguh
const std = @import("std");

fn stringsEqual(s1: []const u8, s2: []const u8) bool {
    if (s1.len != s2.len) {
        return false;
    }

    for (s1, s2) |c1, c2| {
        if (std.ascii.toLower(c1) != std.ascii.toLower(c2)) {
            return false;
        }
    }

    return true;
}

fn panic(err: anyerror) noreturn {
    std.debug.panic("error {!}\n", .{err});
}

const Question = struct {
    title: []const u8,
    answer: []const u8,
    reward: u8,

    pub const Raw = struct {
        title: []const u8,
        answer: []const u8,
        reward: u8,
    };

    pub fn init(title: []const u8, answer: []const u8, reward: u8) Question {
        return Question{ .title = title, .answer = answer, .reward = reward };
    }

    pub fn fromRaw(raw: Raw) Question {
        return Question{ .title = raw.title, .answer = raw.answer, .reward = raw.rewad };
    }

    pub fn ask(self: *const Question) u8 {
        const stdout = std.io.getStdOut().writer();
        const stdin = std.io.getStdIn().reader();
        var buf: [50]u8 = std.mem.zeroes([50]u8);

        const pointsTxt = if (self.reward == 1) "point" else "points";

        stdout.print("{s}\u{001b}[0;2m (for \u{001b}[0;1m{} {s}\u{001b}[0;2m)\n    \u{001b}[34m(?) \u{001b}[0;2m", .{ self.title, self.reward, pointsTxt }) catch |err| panic(err);
        const userAnswer = stdin.readUntilDelimiter(&buf, '\n') catch |err| panic(err);
        stdout.writeAll("\u{001b}[0m") catch |err| panic(err);

        if (stringsEqual(self.answer, userAnswer)) {
            return self.reward;
        } else {
            return 0;
        }
    }
};

const SetBuilder = struct {
    alloc: std.mem.Allocator,
    title: []const u8,
    questions: std.ArrayList(Question),

    pub fn init(alloc: std.mem.Allocator) SetBuilder {
        var res = SetBuilder{ .alloc = alloc, .title = undefined, .questions = undefined };
        res.questions = std.ArrayList(Question).init(res.alloc);
        return res;
    }

    pub fn setTitle(self: *SetBuilder, title: []const u8) *SetBuilder {
        self.title = title;
        return self;
    }

    pub fn addQuestion(self: *SetBuilder, question: Question) *SetBuilder {
        self.questions.append(question) catch |err| panic(err);
        return self;
    }

    pub fn build(self: *const SetBuilder) Set {
        return Set{ .title = self.title, .questions = self.questions };
    }
};

const Set = struct {
    title: []const u8,
    questions: std.ArrayList(Question),

    pub const Raw = struct {
        title: []const u8,
        questions: []Question,
    };

    pub fn fromRaw(alloc: std.mem.Allocator, raw: Raw) Set {
        var questions = std.ArrayList(Question).init(alloc);
        questions.appendSlice(raw.questions) catch |err| panic(err);
        return Set{ .title = raw.title, .questions = questions };
    }

    pub fn builder(alloc: std.mem.Allocator) SetBuilder {
        return SetBuilder.init(alloc);
    }

    pub fn askQuestions(self: *const Set) u32 {
        const stdout = std.io.getStdOut().writer();
        var score: u32 = 0;

        stdout.print("\u{001b}[1m{s}\u{001b}[0m\n==========\n", .{self.title}) catch |err| panic(err);

        for (self.questions.items, 0..self.questions.items.len) |question, counter| {
            stdout.print("\u{001b}[34m{}. \u{001b}[0m", .{counter + 1}) catch |err| panic(err);
            const reward = question.ask();

            if (reward != 0) {
                stdout.writeAll("    \u{001b}[32;1mCorrect!\u{001b}[0m\n") catch |err| panic(err);
                stdout.print("You get a \u{001b}[32;1m{}\u{001b}[0m point reward.\n\n", .{reward}) catch |err| panic(err);
            } else {
                stdout.writeAll("    \u{001b}[31;1mIncorrect!\u{001b}[0m\n") catch |err| panic(err);
                stdout.writeAll("You get \u{001b}[31;1mno\u{001b}[0m reward.\n\n") catch |err| panic(err);
            }
            score += reward;
        }

        return score;
    }

    pub fn deinit(self: *const Set) void {
        self.questions.deinit();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer {
        _ = gpa.deinit();
    }
    const stdout = std.io.getStdOut().writer();

    // read config
    var config_file = try std.fs.cwd().openFile("askme.json", .{});
    defer config_file.close();
    var config_br = std.io.bufferedReader(config_file.reader());
    const config_br_reader = config_br.reader();

    const content = try config_br_reader.readAllAlloc(alloc, 4096);
    defer alloc.free(content);

    const raw_config = try std.json.parseFromSlice(Set.Raw, alloc, content, .{});
    defer raw_config.deinit();

    const set = Set.fromRaw(alloc, raw_config.value);
    defer set.deinit();

    const score = set.askQuestions();
    try stdout.print("==========\n\u{001b}[0;2mwow! you got \u{001b}[0;32m{} points.\u{001b}[0m\n", .{score});
}
