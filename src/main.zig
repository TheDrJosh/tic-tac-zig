const std = @import("std");

const Board = [9]?Player;

fn min_max_node(comptime children: u8) type {
    if (children > 0) {
        return struct {
            board: Board,
            children: [children]min_max_node(children - 1),
        };
    } else {
        return struct {
            board: Board,
        };
    }
}

fn init_min_max_node(comptime children: u8, board: Board, active_player: Player) min_max_node(children) {
    if (children > 0) {
        var children_nodes: [children]min_max_node(children - 1) = undefined;
        var node_index: u8 = 0;
        for (0..9) |i| {
            if (board[i] == null) {
                var new_board: Board = undefined;
                @memcpy(&new_board, &board);
                new_board[i] = active_player;
                children_nodes[node_index] = init_min_max_node(children - 1, new_board, active_player.other());
                node_index += 1;
            }
        }

        return min_max_node(children){ .board = board, .children = children_nodes };
    } else {
        return min_max_node(children){
            .board = board,
        };
    }
}

fn min_max_tree() min_max_node(9) {
    var board = Board{ null, null, null, null, null, null, null, null, null };
    return init_min_max_node(9, board);
}

const Player = enum {
    X,
    O,
    fn other(self: *const Player) Player {
        switch (self.*) {
            Player.X => {
                return Player.O;
            },
            Player.O => {
                return Player.X;
            },
        }
    }
    fn to_letter(self: *const Player) u8 {
        switch (self.*) {
            Player.X => {
                return 'X';
            },
            Player.O => {
                return 'O';
            },
        }
    }
    fn to_letter_optional(self: *const ?Player) u8 {
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

const WinState = enum {
    X,
    O,
    Cats,
    fn from_player(player: *const Player) WinState {
        switch (player.*) {
            Player.X => return WinState.X,
            Player.O => return WinState.O,
        }
    }
};

const GameState = struct {
    board: Board,
    active_player: Player,
    computer_player: ?Player,

    fn new(start_player: Player, computer_player: ?Player) GameState {
        return GameState{
            .active_player = start_player,
            .board = Board{ null, null, null, null, null, null, null, null, null },
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

        self.draw_line(0);
        GameState.draw_line_gap();
        self.draw_line(1);
        GameState.draw_line_gap();
        self.draw_line(2);
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
            if (self.board[input] == null) {
                self.board[input] = self.active_player;
                break;
            } else {
                std.debug.print("position already occupied try anouther spot.\n", .{});
                input = try GameState.get_input();
            }
        }

        self.active_player = self.active_player.other();
        self.draw();
    }

    fn detect_win(board: Board) ?WinState {
        if (((board[0] == board[4] and board[0] == board[8]) or (board[2] == board[4] and board[2] == board[6])) and board[4] != null) {
            return WinState.from_player(&board[4].?);
        }
        var i: u8 = 0;
        while (i < 3) : (i += 1) {
            if ((board[0 + i * 3] == board[1 + i * 3] and board[0 + i * 3] == board[2 + i * 3]) and board[0 + i * 3] != null) {
                return WinState.from_player(&board[0 + i * 3].?);
            }
            if ((board[0 + i] == board[3 + i] and board[0 + i] == board[6 + i]) and board[0 + i] != null) {
                return WinState.from_player(&board[0 + i].?);
            }
        }

        var is_cats: bool = true;

        for (board) |cell| {
            is_cats = is_cats and cell != null;
        }

        if (is_cats) {
            return WinState.Cats;
        }

        return null;
    }

    fn play(self: *GameState) !void {
        self.draw();
        while (true) {
            try self.turn();
            var winner = GameState.detect_win(self.board);
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

    var state = GameState.new(Player.X, Player.O);

    try state.play();

    // var mmt = try MinMaxTree.new(Player.X, gpa.allocator());
    // std.debug.print("minmax made\n", .{});

    // mmt.populate_wins();
    // std.debug.print("{any}\n", .{mmt});
    // defer mmt.deinit();
    var board = Board{ null, null, null, null, null, null, null, null, null };

    var tree: min_max_node(9) = init_min_max_node(9, board, Player.X);
    _ = tree;

    // std.debug.print("{any}\n", .{tree});
}
