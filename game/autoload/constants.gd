extends Node

enum CompressionLevel {
	PAUSED,
	SLOW,    # 1 yr/s
	NORMAL,  # 5 yr/s
	FAST,    # 20 yr/s
	FASTER,  # 100 yr/s
	MAX,     # 500 yr/s
}

const YEARS_PER_SECOND := {
	CompressionLevel.PAUSED: 0.0,
	CompressionLevel.SLOW: 1.0,
	CompressionLevel.NORMAL: 5.0,
	CompressionLevel.FAST: 20.0,
	CompressionLevel.FASTER: 100.0,
	CompressionLevel.MAX: 500.0,
}

const COMPRESSION_LABELS := {
	CompressionLevel.PAUSED: "Paused",
	CompressionLevel.SLOW: "1x (1 yr/s)",
	CompressionLevel.NORMAL: "5x (5 yr/s)",
	CompressionLevel.FAST: "20x (20 yr/s)",
	CompressionLevel.FASTER: "100x (100 yr/s)",
	CompressionLevel.MAX: "500x (500 yr/s)",
}
