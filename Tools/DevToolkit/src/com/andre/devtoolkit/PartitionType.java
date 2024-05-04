package com.andre.devtoolkit;

/**
 *
 * @author Andre
 */
public enum PartitionType {
	UNKNOWN(-1, "Unknown"),
	EMPTY(0, "Empty"),
	FAT16(0x0E, "FAT 16");
	
	public final int TYPE_ID;
	public final String NAME;
	
	private PartitionType(int typeId, String name) {
		this.TYPE_ID = typeId;
		this.NAME = name;
	}
	
	public static PartitionType fromByteId(int id) {
		switch (id) {
			case 0 -> { return EMPTY; }
			case 0x0E -> { return FAT16; }
		}
		
		return UNKNOWN;
	}
} 
