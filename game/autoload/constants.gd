extends Node

enum CompressionLevel {
	PAUSED,
	SLOW,    # 0.2 yr/s  — careful play, reading events
	NORMAL,  # 1 yr/s    — standard
	FAST,    # 5 yr/s    — mid-game cruise
	FASTER,  # 20 yr/s   — late K1 / between events
	MAX,     # 100 yr/s  — K2+ timescales
}

const YEARS_PER_SECOND := {
	CompressionLevel.PAUSED: 0.0,
	CompressionLevel.SLOW: 0.2,
	CompressionLevel.NORMAL: 1.0,
	CompressionLevel.FAST: 5.0,
	CompressionLevel.FASTER: 20.0,
	CompressionLevel.MAX: 100.0,
}

const COMPRESSION_LABELS := {
	CompressionLevel.PAUSED: "Paused",
	CompressionLevel.SLOW: "0.2x",
	CompressionLevel.NORMAL: "1x",
	CompressionLevel.FAST: "5x",
	CompressionLevel.FASTER: "20x",
	CompressionLevel.MAX: "100x",
}
