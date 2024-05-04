package com.andre.devtoolkit;

import java.io.File;

/**
 *
 * @author Andre
 */
public class DiskPartition {
	private final File disk;
	private final int id;
	private final PartitionType type;
	private final int typeId;
	private int firstSector;
	private int sizeInSectors;
	
	DiskPartition(int id, File disk, byte[] entry, int offset) {
		this.id = id;
		this.disk = disk;
		
		this.typeId = entry[offset + 0x04] & 0xFF;
		type = PartitionType.fromByteId(typeId);
		if (this.typeId == 0) return;
		
		int sectors = Numbers.byteArrayToInt(entry, offset + 0x0C);
		this.sizeInSectors = sectors;
		
		int start = Numbers.byteArrayToInt(entry, offset + 0x08);
		this.firstSector = start;
	}

	public File getDisk() {
		return disk;
	}
	
	public int getFirstSector() {
		return firstSector;
	}
	
	public PartitionType getType() {
		return type;
	}
	
	private String getSizeDescription() {
		int sizeInKB = sizeInSectors / 2;
		if (sizeInKB < 8192) {
			return sizeInKB + " KiB";
		}
		
		int sizeInMB = sizeInKB / 1024;
		if (sizeInMB < 8192) {
			return sizeInMB + " MiB";
		}
		
		int sizeInGB = sizeInMB / 1024;
		return sizeInGB + " GiB";
	}
	
	private String getTypeDescription() {
		return type.NAME;
	}
	
	@Override
	public String toString() {
		var typeStr = getTypeDescription();
		var sizeStr = getSizeDescription();
		return String.format("[%d] 0x%02X='%s' : %s : 0x%02X", id, type, typeStr, sizeStr, firstSector);
	}
}
