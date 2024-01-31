const std = @import("std");
const min_max = @import("min_max.zig");

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
            if (cell != null) {
                try moves.append(i);
            }
        }
        return moves;
    }

    // def minimax(game)
    //     return score(game) if game.over?
    //     scores = [] # an array of scores
    //     moves = []  # an array of moves

    //     # Populate the scores array, recursing as needed
    //     game.get_available_moves.each do |move|
    //         possible_game = game.get_new_state(move)
    //         scores.push minimax(possible_game)
    //         moves.push move
    //     end

    //     # Do the min or the max calculation
    //     if game.active_turn == @player
    //         # This is the max calculation
    //         max_score_index = scores.each_with_index.max[1]
    //         @choice = moves[max_score_index]
    //         return scores[max_score_index]
    //     else
    //         # This is the min calculation
    //         min_score_index = scores.each_with_index.min[1]
    //         @choice = moves[min_score_index]
    //         return scores[min_score_index]
    //     end
    // end
    fn minmax(self: *const Board, active_turn: Player, computer: Player, allocator: std.mem.Allocator) !i32 {
        if (self.win_state()) |winner| {
            return winner.to_number();
        }
        var scores = std.ArrayList(i32).init(allocator);
        defer scores;
        var moves = std.ArrayList(usize).init(allocator);
        defer moves.deinit();

        const av_moves = try self.available_moves(allocator);
        defer av_moves.deinit();

        for (av_moves.items) |move| {
            var new_board: Board = undefined;
            @memcpy(&new_board, &self);
            new_board.inner[move] = active_turn;
            try scores.append(new_board.minmax(active_turn.other(), computer, allocator));
            try moves.append(move);
        }

        if (active_turn == computer) {
            var max_score_index = null;
            _ = max_score_index;
            var max_score = null;
            _ = max_score;
        }

        errdefer scores.deinit();
    }
    pub fn draw_line(self: *const Board, line: u8) void {
        std.debug.print("{c}|{c}|{c}\n", .{ Player.to_letter_optional(&self.inner[0 + line * 3]), Player.to_letter_optional(&self.inner[1 + line * 3]), Player.to_letter_optional(&self.inner[2 + line * 3]) });
    }

    pub fn draw_line_gap() void {
        std.debug.print("-+-+-\n", .{});
    }

    pub fn draw(self: *const Board) void {
        self.draw_line(0);
        Board.draw_line_gap();
        self.draw_line(1);
        Board.draw_line_gap();
        self.draw_line(2);
    }
};

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

    fn new(start_player: Player, computer_player: ?Player) GameState {
        return GameState{
            .active_player = start_player,
            .board = Board.empty(),
            .computer_player = computer_player,
        };
    }

    fn deinit(self: GameState) void {
        self.min_max.deinit();
    }

    fn draw_line(self: *GameState, line: u8) void {
        std.debug.print("{c}|{c}|{c}\n", .{ Player.to_letter_optional(&self.board[0 + line * 3]), Player.to_letter_optional(&self.board[1 + line * 3]), Player.to_letter_optional(&self.board[2 + line * 3]) });
    }

    fn draw_line_gap() void {
        std.debug.print("-+-+-\n", .{});
    }

    fn draw(self: *GameState) void {
        std.debug.print("It is {c}'s turn.\n", .{self.active_player.to_letter()});

        self.board.draw();
    }

    fn get_input() !u8 {
        const stdin = std.io.getStdIn().reader();

        var buf: [1024]u8 = undefined;

        std.debug.print("Input must be in form \"x:y\" ex: 1:1.\n", .{});

        while (try stdin.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 4 and line[1] == ':') {
                var x: ?u8 = null;
                var y: ?u8 = null;

                switch (line[0]) {
                    '1' => x = 0,
                    '2' => x = 1,
                    '3' => x = 2,
                    else => std.debug.print("{c} is not a valid column.\n", .{line[0]}),
                }

                switch (line[2]) {
                    '1' => y = 0,
                    '2' => y = 1,
                    '3' => y = 2,
                    else => std.debug.print("{c} is not a valid row.\n", .{line[2]}),
                }

                if (x != null and y != null) {
                    return x.? + y.? * 3;
                }
            } else {
                std.debug.print("incorrect input format.\n", .{});
            }
        }

        return 0;
    }

    fn turn(self: *GameState) !void {
        var input = try GameState.get_input();

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

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const start_player = Player.X;

    // var tree = min_max_tree(start_player, gpa.allocator());

    // std.debug.print("{any}\n", .{tree});

    var state = GameState.new(start_player, Player.O);

    try state.play();
}

test "board numbers" {
    var board = Board{ .inner = .{ null, Player.X, Player.O, null, null, Player.O, null, Player.X, Player.X } };
    var board_number = board.get_number();
    var number_board = Board.from_number(board_number);

    try std.testing.expect(std.mem.eql(?Player, &board.inner, &number_board.inner));
}

test "min max tree" {
    // std.debug.print("\n", .{});

    var tree = try min_max.MinMaxTree.init(std.testing.allocator);
    defer tree.deinit();

    var index: ?usize = 0;

    while (index) |i| {
        if (tree.all_boards[i]) |*node| {
            if (node.children.items.len > 0) {
                var move = node.children.items[0];
                Board.from_number(i).draw();
                std.debug.print("{c} went\nid: {d}\n\n", .{ move.moved.to_letter(), i });
                index = move.index;
            } else {
                index = null;
            }
        } else {
            index = null;
        }
    }
}

test "min max predict" {
    Board.from_number(14076).draw();
    std.debug.print("\n\n", .{});
    Board.from_number(14077).draw();

    var tree = try min_max.MinMaxTree.init(std.testing.allocator);
    defer tree.deinit();

    Board.from_number(14076).draw();
    std.debug.print("{any}\n", .{tree.all_boards[14076].?.children.items});

    std.debug.print("\n\n", .{});
    Board.from_number(14077).draw();
    std.debug.print("{any}\n", .{tree.all_boards[14077].?.children.items});

    var test_board = Board.from_number(0);

    var res = tree.get_best_move(&test_board, Player.X);
    _ = res;

    // std.debug.print("{any}", .{res});
}
