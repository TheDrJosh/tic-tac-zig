const std = @import("std");

// const rogueutil = @cImport(@cInclude("rogueutil.h"));
// const rogueutil = @import("rogueutil.zig");
const termlib = @import("term");

pub const Board = struct {
    inner: [9]?Player,

    fn empty() Board {
        return Board{ .inner = .{ null, null, null, null, null, null, null, null, null } };
    }

    pub fn get_number(self: *const Board) usize {
        var number: usize = 0;

        for (0..self.inner.len) |i| {
            if (self.inner[i] != null) {
                switch (self.inner[i].?) {
                    Player.X => number += std.math.pow(usize, 3, i),
                    Player.O => number += std.math.pow(usize, 3, i) * 2,
                }
            }
        }

        return number;
    }
    pub fn from_number(number: usize) Board {
        var board = Board{ .inner = .{ null, null, null, null, null, null, null, null, null } };

        for (0..board.inner.len) |i| {
            switch ((number / std.math.pow(usize, 3, i)) % 3) {
                0 => {},
                1 => board.inner[i] = Player.X,
                2 => board.inner[i] = Player.O,
                else => unreachable,
            }
        }

        return board;
    }
    pub fn win_state(self: *const Board) ?WinState {
        if (((self.inner[0] == self.inner[4] and self.inner[0] == self.inner[8]) or (self.inner[2] == self.inner[4] and self.inner[2] == self.inner[6])) and self.inner[4] != null) {
            return WinState.from_player(&self.inner[4].?);
        }
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            if ((self.inner[0 + i * 3] == self.inner[1 + i * 3] and self.inner[0 + i * 3] == self.inner[2 + i * 3]) and self.inner[0 + i * 3] != null) {
                return WinState.from_player(&self.inner[0 + i * 3].?);
            }
            if ((self.inner[0 + i] == self.inner[3 + i] and self.inner[0 + i] == self.inner[6 + i]) and self.inner[0 + i] != null) {
                return WinState.from_player(&self.inner[0 + i].?);
            }
        }

        var is_cats: bool = true;

        for (self.inner) |cell| {
            is_cats = is_cats and cell != null;
        }

        if (is_cats) {
            return WinState.Cats;
        }

        return null;
    }
    pub fn next_boards(board: *const Board, active_player: Player) []BoardMove {
        _ = active_player;
        if (board.win_state() != null) {
            return &[0]BoardMove{};
        }

        var boards: [18]BoardMove = undefined;
        @memset(&boards, BoardMove{ .board = Board.empty(), .moved = .X });
        var j: usize = 0;

        var xs: u8 = 0;
        var os: u8 = 0;

        for (board.inner) |cell| {
            if (cell != null) {
                switch (cell.?) {
                    Player.X => xs += 1,
                    Player.O => os += 1,
                }
            }
        }

        for (0..9) |i| {
            if (board.inner[i] == null) {
                if (xs <= os) {
                    var new_board_x: Board = Board{ .inner = undefined };
                    @memcpy(&new_board_x.inner, &board.inner);
                    new_board_x.inner[i] = Player.X;
                    boards[j] = BoardMove{ .board = new_board_x, .moved = Player.X };
                    j += 1;
                }
                if (xs >= os) {
                    var new_board_o: Board = Board{ .inner = undefined };
                    @memcpy(&new_board_o.inner, &board.inner);
                    new_board_o.inner[i] = Player.O;
                    boards[j] = BoardMove{ .board = new_board_o, .moved = Player.O };
                    j += 1;
                }
            }
        }
        return boards[0..j];
    }

    fn available_moves(self: *const Board, allocator: std.mem.Allocator) !std.ArrayList(usize) {
        var moves = std.ArrayList(usize).init(allocator);
        errdefer moves.deinit();
        for (self.inner, 0..) |cell, i| {
            if (cell == null) {
                try moves.append(i);
            }
        }
        return moves;
    }

    pub fn draw_line_gap() void {
        std.debug.print("-+-+-\n", .{});
    }
    pub fn draw_line(self: *const Board, line: u8) void {
        std.debug.print("{c}|{c}|{c}\n", .{ Player.to_letter_optional(&self.inner[0 + line * 3]), Player.to_letter_optional(&self.inner[1 + line * 3]), Player.to_letter_optional(&self.inner[2 + line * 3]) });
    }

    pub fn draw(self: *const Board) void {
        self.draw_line(0);
        Board.draw_line_gap();
        self.draw_line(1);
        Board.draw_line_gap();
        self.draw_line(2);
    }
};

const MinMaxResult = struct { score: i32, choice: ?u8 };

pub const BoardMove = struct {
    board: Board,
    moved: Player,
};

pub const Player = enum {
    X,
    O,
    pub fn other(self: *const Player) Player {
        switch (self.*) {
            Player.X => {
                return Player.O;
            },
            Player.O => {
                return Player.X;
            },
        }
    }
    pub fn to_letter(self: *const Player) u8 {
        switch (self.*) {
            Player.X => {
                return 'X';
            },
            Player.O => {
                return 'O';
            },
        }
    }
    pub fn to_letter_optional(self: *const ?Player) u8 {
        if (self.* != null) {
            switch (self.*.?) {
                Player.X => return 'X',
                Player.O => return 'O',
            }
        } else {
            return ' ';
        }
    }
};

pub const WinState = enum {
    X,
    O,
    Cats,
    fn from_player(player: *const Player) WinState {
        switch (player.*) {
            Player.X => return WinState.X,
            Player.O => return WinState.O,
        }
    }
    pub fn to_number(self: *const WinState) i32 {
        return switch (self.*) {
            .X => 1,
            .O => -1,
            .Cats => 0,
        };
    }
};

const GameState = struct {
    board: Board,
    active_player: Player,
    computer_player: ?Player,
    allocator: std.mem.Allocator,

    fn new(start_player: Player, computer_player: ?Player, allocator: std.mem.Allocator) GameState {
        return GameState{
            .active_player = start_player,
            .board = Board.empty(),
            .computer_player = computer_player,
            .allocator = allocator,
        };
    }

    fn deinit(self: GameState) void {
        self.min_max.deinit();
    }

    fn draw(self: *GameState) void {
        std.debug.print("It is {c}'s turn.\n", .{self.active_player.to_letter()});

        self.board.draw();
    }

    fn minmax(
        self: *const GameState,
        idepth: i32,
    ) !MinMaxResult {
        if (self.board.win_state()) |winner| {
            return MinMaxResult{ .score = winner.to_number() * 10 - idepth, .choice = null };
        }
        var depth = idepth + 1;

        var scores = std.ArrayList(i32).init(self.allocator);
        defer scores.deinit();
        var moves = std.ArrayList(usize).init(self.allocator);
        defer moves.deinit();

        const av_moves = try self.board.available_moves(self.allocator);
        defer av_moves.deinit();

        for (av_moves.items) |move| {
            var new_board: Board = Board.empty();
            @memcpy(&new_board.inner, &self.board.inner);
            new_board.inner[move] = self.active_player;
            var new_game_state = GameState{
                .board = new_board,
                .active_player = self.active_player.other(),
                .computer_player = self.computer_player,
                .allocator = self.allocator,
            };

            try scores.append((try new_game_state.minmax(depth)).score);
            try moves.append(move);
        }

        var score_index: usize = 0;

        for (scores.items, 0..) |score, i| {
            if (self.active_player == self.computer_player) {
                if (score < scores.items[score_index]) {
                    score_index = i;
                }
            } else {
                if (score > scores.items[score_index]) {
                    score_index = i;
                }
            }
        }

        return MinMaxResult{ .score = scores.items[score_index], .choice = @truncate(moves.items[score_index]) };
    }
    fn get_input() !u8 {
        const stdin = std.io.getStdIn().reader();

        var buf: [1024]u8 = undefined;

        std.debug.print("Input must be in form \"x:y\" ex: 1:1.\n", .{});

        while (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 4 and line[1] == ':') {
                var x: u8 = switch (line[0]) {
                    '1' => 0,
                    '2' => 1,
                    '3' => 2,
                    else => {
                        std.debug.print("{c} is not a valid column.\n", .{line[0]});
                        continue;
                    },
                };
                var y: u8 = switch (line[2]) {
                    '1' => 0,
                    '2' => 1,
                    '3' => 2,
                    else => {
                        std.debug.print("{c} is not a valid row.\n", .{line[2]});
                        continue;
                    },
                };
                return x + y * 3;
            } else {
                std.debug.print("incorrect input format.\n", .{});
            }
        }
        return try get_input();
    }

    fn turn(self: *GameState) !void {
        var c_input: ?u8 = null;
        if (self.computer_player) |cp| {
            if (cp == self.active_player) {
                if ((try self.minmax(0)).choice) |choice| {
                    c_input = choice;
                }
            }
        }

        var input = if (c_input) |ci| ci else try GameState.get_input();

        while (true) {
            if (self.board.inner[input] == null) {
                self.board.inner[input] = self.active_player;
                break;
            } else {
                std.debug.print("position already occupied try anouther spot.\n", .{});
                input = try GameState.get_input();
            }
        }

        self.active_player = self.active_player.other();
        self.draw();
    }

    fn play(self: *GameState) !void {
        self.draw();
        while (true) {
            try self.turn();
            var winner = self.board.win_state();
            if (winner != null) {
                switch (winner.?) {
                    WinState.X => std.debug.print("X Won!\n", .{}),
                    WinState.O => std.debug.print("O Won!\n", .{}),
                    WinState.Cats => std.debug.print("It was a cat's game.\n", .{}),
                }
                break;
            }
        }
    }
};

fn ginput() !?[]u8 {
    const stdin = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;

    return try stdin.readUntilDelimiterOrEof(&buf, '\n');
}

fn main_menu(allocator: std.mem.Allocator) !GameState {
    std.debug.print("How many players?: (1 or 2)\n", .{});
    var is_multiplayer: ?bool = null;

    while (is_multiplayer == null) {
        if (try ginput()) |player_count_input| {
            if (player_count_input.len == 2) {
                if (player_count_input[0] == '1') {
                    is_multiplayer = false;
                    break;
                } else if (player_count_input[0] == '2') {
                    is_multiplayer = true;
                    break;
                }
            }
        }
        std.debug.print("Invalid Input\n", .{});
    }

    std.debug.print("Who goes first?: (X or O)\n", .{});
    var start_player: ?Player = null;

    while (start_player == null) {
        if (try ginput()) |start_player_input| {
            if (start_player_input.len == 2) {
                if (start_player_input[0] == 'X' or start_player_input[0] == 'x') {
                    start_player = Player.X;
                    break;
                } else if (start_player_input[0] == 'O' or start_player_input[0] == 'o') {
                    start_player = Player.O;
                    break;
                }
            }
        }
        std.debug.print("Invalid Input\n", .{});
    }

    if (is_multiplayer orelse true) {
        return GameState.new(start_player orelse Player.X, null, allocator);
    } else {
        std.debug.print("What is the computer?: (X or O)\n", .{});
        var computer_player: ?Player = null;
        while (computer_player == null) {
            if (try ginput()) |computer_player_input| {
                if (computer_player_input.len == 2) {
                    if (computer_player_input[0] == 'X' or computer_player_input[0] == 'x') {
                        computer_player = Player.X;
                        break;
                    } else if (computer_player_input[0] == 'O' or computer_player_input[0] == 'o') {
                        computer_player = Player.O;
                        break;
                    }
                }
            }
            std.debug.print("Invalid Input\n", .{});
        }

        std.debug.print("What is the difficulty?: (1, 2, or 3)\n", .{});
        var computer_difficulty: ?Difficulty = null;
        while (computer_difficulty == null) {
            if (try ginput()) |computer_difficulty_input| {
                if (computer_difficulty_input.len == 2) {
                    if (computer_difficulty_input[0] == '1') {
                        computer_difficulty = Difficulty.Easy;
                        break;
                    } else if (computer_difficulty_input[0] == '2') {
                        computer_difficulty = Difficulty.Medium;
                        break;
                    } else if (computer_difficulty_input[0] == '3') {
                        computer_difficulty = Difficulty.Hard;
                        break;
                    }
                }
            }
            std.debug.print("Invalid Input\n", .{});
        }

        return GameState.new(start_player orelse Player.X, computer_player orelse Player.O, allocator);
    }
}

const Difficulty = enum {
    Easy,
    Medium,
    Hard,
};

//use (https://github.com/sakhmatd/rogueutil) to test c intergration

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    // var state = try main_menu(gpa.allocator());

    // try state.play();
    var term = termlib.Term.init(gpa.allocator());
    defer term.deinit();

    try term.setColor(7, 0);
    try term.setAttribute(.Italic);
    try term.setCell(10, 10, 'X');
    try term.setCellUtf8(12, 10, "Ö");

    while (true) {
        var evt = try term.pollEvent();

        // if (needs_to_terminate) break;

        if (evt == .key) {}
        // do something...

        term.update();
    }
}

test "board numbers" {
    var board = Board{ .inner = .{ null, Player.X, Player.O, null, null, Player.O, null, Player.X, Player.X } };
    var board_number = board.get_number();
    var number_board = Board.from_number(board_number);

    try std.testing.expect(std.mem.eql(?Player, &board.inner, &number_board.inner));
}

test "min max predict" {
    var test_board = Board.from_number(0);

    var res = test_board.minmax(Player.O, Player.X, std.testing.allocator);

    std.debug.print("{any}", .{res});
}
