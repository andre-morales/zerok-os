package com.andre.devtoolkit;

import java.util.Arrays;

/**
 *
 * @author Andre
 */
public enum PartitionType {
	UNKNOWN(-1, "Unknown"),
	EMPTY(0, "Empty"),
	FAT16B_LBA(0x0E, "FAT 16B (LBA)"),
	EXTENDED_LBA(0x0F, "Extended (LBA)");
	
	public final int typeId;
	public final String description;
	
	private PartitionType(int typeId, String name) {
		this.typeId = typeId;
		this.description = name;
	}
	
	public static PartitionType fromByteId(int id) {
		var enumValues = PartitionType.values();
		var type = Arrays.stream(enumValues)
				.filter((pt) -> pt.typeId == id)
				.findFirst();
	
		return type.orElse(UNKNOWN);
	}
	
	public boolean isExtended() {
		return this == EXTENDED_LBA;
	}
} 
