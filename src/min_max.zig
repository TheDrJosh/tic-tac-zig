const std = @import("std");
const main = @import("main.zig");

const MinMaxNode = struct {
    children: std.ArrayList(MinMaxLink),
};
const MinMaxLink = struct { index: usize, moved: main.Player };

const POSIBLE_BOARDS = main.Board.get_number(&main.Board{ .inner = .{ main.Player.O, main.Player.O, main.Player.O, main.Player.O, main.Player.O, main.Player.O, main.Player.O, main.Player.O, main.Player.O } }) + 1;

pub const MinMaxTree = struct {
    all_boards: [POSIBLE_BOARDS]?MinMaxNode,
    pub fn init(allocator: std.mem.Allocator) !MinMaxTree {
        var all_boards: [POSIBLE_BOARDS]?MinMaxNode = undefined;
        @memset(&all_boards, null);

        for (0..all_boards.len) |i| {
            var board = main.Board.from_number(i);
            var children_boards = board.next_boards();
            var children = std.ArrayList(MinMaxLink).init(allocator);
            errdefer children.deinit();

            for (0..children_boards.len) |j| {
                var child_board = children_boards[j];
                try children.append(MinMaxLink{ .index = child_board.board.get_number(), .moved = child_board.moved });
            }

            all_boards[i] = MinMaxNode{ .children = children };
        }

        return MinMaxTree{ .all_boards = all_boards };
    }
    pub fn deinit(self: *MinMaxTree) void {
        for (self.all_boards) |board| {
            if (board) |b| {
                b.children.deinit();
            }
        }
    }

    // pub fn get_best_move(self: *const MinMaxTree, board: *main.Board, active_player: main.Player) Move {

    //     if (main.Board.from_number(board).win_state()) |winner| {
    //         return winner
    //     }

    //     const board_id = board.get_number();

    //     var move = self.win_value(board_id, active_player);

    //     for (board.inner, main.Board.from_number(move.index.?).inner, 0..) |cell_a, cell_b, i| {
    //         if (cell_a == null and cell_b == active_player) {
    //             return Move{
    //                 .cell = i,
    //                 .player = active_player,
    //             };
    //         }
    //     }
    //     return null;
    // }

    fn win_value(self: *const MinMaxTree, board: usize, active_player: main.Player) WinResult {
        // std.debug.print("board: {d}\n", .{board});
        if (self.all_boards[board]) |*node| {
            if (node.children.items.len == 0) {
                if (main.Board.from_number(board).win_state()) |win| {
                    return WinResult{ .wins = win.to_number(), .index = null };
                } else {
                    @panic("board has no children but not a win");
                }
            }

            var win: ?WinResult = null;
            for (node.children.items) |child| {
                if (child.moved == active_player) {
                    if (win) |w| {
                        var new_wins = self.win_value(child.index, active_player.other());
                        if (new_wins.wins > w.wins) {
                            win = new_wins;
                        }
                    } else {
                        win = self.win_value(child.index, active_player.other());
                    }
                }
            }
            if (win) |w| {
                return w;
            } else {
                @panic("no valid moves");
            }
        } else {
            @panic("not a valid node");
        }
    }
};

const WinResult = struct {
    wins: i32,
    index: ?usize,
};

fn win_to_num(win: ?main.WinState) ?i32 {
    if (win == null) {
        return null;
    } else {
        switch (win.?) {
            main.WinState.X => return 1,
            main.WinState.O => return -1,
            main.WinState.Cats => return 0,
        }
    }
}

const Move = struct {
    cell: usize,
    player: main.Player,
};
