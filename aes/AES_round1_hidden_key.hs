
main : [128] -> Bit
main input = AESRound_2 x ! 0 where
	[x] = transpose (split input)

type AES128 = 4
type Nk = AES128
type Nb = 4
type Nr = 6 + Nk
type AESKeySize = (Nk*32)

type GF28 = [8]
type State = [4][Nb]GF28
type RoundKey = State
type KeySchedule = (RoundKey, [Nr-1]RoundKey, RoundKey)

// GF28 operations
gf28Add : {n} (fin n) => [n]GF28 -> GF28
gf28Add ps = sums ! 0
	where	sums = [zero] # [ p ^ s | p <- ps | s <- sums ]

irreducible = <| x^^8 + x^^4 + x^^3 + x + 1 |>

gf28Mult : (GF28, GF28) -> GF28
gf28Mult (x, y) = pmod(pmult x y) irreducible

gf28Pow : (GF28, [8]) -> GF28
gf28Pow (n, k) = pow k
	where	pow i = if i == 0 then 1
				else if odd i
					then gf28Mult(n, sq (pow (i >> 1)))
					else sq (pow (i >> 1))
	where	sq x = gf28Mult (x, x)
	where	odd x = x ! 0

gf28Inverse : GF28 -> GF28
gf28Inverse x = gf28Pow (x, 254)

gf28DotProduct : {n} (fin n) => ([n]GF28, [n]GF28) -> GF28
gf28DotProduct (xs, ys) = gf28Add [ gf28Mult (x, y) | x <- xs | y <- ys ]

gf28VectorMult : {n, m} (fin n) => ([n]GF28, [m][n]GF28) -> [m]GF28
gf28VectorMult (v, ms) = [ gf28DotProduct(v, m) | m <- ms ]

gf28MatrixMult : {n, m, k} (fin m) => ([n][m]GF28, [m][k]GF28) -> [n][k]GF28
gf28MatrixMult (xss, yss) = [ gf28VectorMult(xs, yss') | xs <- xss ]
	where yss' = transpose yss

// The affine transform and its inverse
xformByte : GF28 -> GF28
xformByte b = gf28Add [b, (b >>> 4), (b >>> 5), (b >>> 6), (b >>> 7), c]
	where c = 0x63

xformByte' : GF28 -> GF28
xformByte' b = gf28Add [(b >>> 2), (b >>> 5), (b >>> 7), d] where d = 0x05

// The SubBytes transform and its inverse
SubByte : GF28 -> GF28
SubByte b = xformByte (gf28Inverse b)

SubByte' : GF28 -> GF28
SubByte' b = sbox@b

SubBytes : State -> State
SubBytes state = [ [ SubByte' b | b <- row ] | row <- state ]

// The ShiftRows transform and its inverse
ShiftRows : State -> State
ShiftRows state = [ row <<< shiftAmount | row <- state | shiftAmount <- [0 .. 3]]

// The MixColumns transform and its inverse
MixColumns : State -> State
MixColumns state = gf28MatrixMult (m, state)
	where m = 	[[2, 3, 1, 1],
			[1, 2, 3, 1],
			[1, 1, 2, 3],
			[3, 1, 1, 2]]


// The AddRoundKey transform
AddRoundKey : (RoundKey, State) -> State
AddRoundKey (rk, s) = rk ^ s

// AES rounds and inverses
AESRound : (RoundKey, State) -> State
AESRound (rk, s) = AddRoundKey (rk, MixColumns (ShiftRows (SubBytes s)))

// AES rounds and inverses
AESRound_2 : [128] -> [128]
AESRound_2 s = join(join(AddRoundKey (rk_2, MixColumns (ShiftRows (SubBytes s_4)))))
	where s_4 = groupBy`{4} (groupBy`{8} s_3)
	where s_3 = join(join(AddRoundKey (rk_2, MixColumns (ShiftRows (SubBytes s_2)))))
	where s_2 = groupBy`{4} (groupBy`{8} s)
	where rk_2 = groupBy`{4} (groupBy`{8} rk)
//	where rk = 11110000111100001111000011110000111100001111000011110000111100001111000011110000111100001111000011110000111100001111000011110000
	where rk = 3:[128]

sbox : [256]GF28
sbox = [
0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67,
0x2b, 0xfe, 0xd7, 0xab, 0x76, 0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59,
0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0, 0xb7,
0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1,
0x71, 0xd8, 0x31, 0x15, 0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05,
0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75, 0x09, 0x83,
0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29,
0xe3, 0x2f, 0x84, 0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b,
0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf, 0xd0, 0xef, 0xaa,
0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c,
0x9f, 0xa8, 0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc,
0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2, 0xcd, 0x0c, 0x13, 0xec,
0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19,
0x73, 0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee,
0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb, 0xe0, 0x32, 0x3a, 0x0a, 0x49,
0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4,
0xea, 0x65, 0x7a, 0xae, 0x08, 0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6,
0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a, 0x70,
0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9,
0x86, 0xc1, 0x1d, 0x9e, 0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e,
0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf, 0x8c, 0xa1,
0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0,
0x54, 0xbb, 0x16]

valid _ = True
//grouping = ["l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l",
//"l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l",
//"l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r",
//"r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r",
//"r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r", "r"]

grouping = ["l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l",
"l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l",
"l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l"]


//grouping = ["l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r",
//"l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r",
//"l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r", "l", "l", "r", "r"]
