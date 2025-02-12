const Color = @Vector(4, u8);

const BLACK      =Color{  0,   0,   0, 255};
const WHITE      =Color{255, 255, 255, 255};
const LBLUE1     =Color{195, 220, 229, 255};
const LBLUE2     =Color{163, 190, 204, 255};
const PURPLE1    =Color{ 81,  78,  93, 255};
const PURPLE2    =Color{ 58,  55,  65, 255};
const DARKGRAY1  =Color{ 54,  57,  64, 255};
const DARKGRAY2  =Color{ 34,  36,  38, 255};

const MAGENTA   = Color{255,   0, 255, 255};

pub const DEBUG = MAGENTA;
pub const BACKGROUND  = DARKGRAY2;
pub const GRID_BORDER = BLACK;
pub const TILE_BORDER = DARKGRAY1;
//pub const GRID_BACKGROUND = LBLUE2;
pub const GRID_BACKGROUND = WHITE;
