package com.andre.devtoolkit;

import java.io.File;

/**
 *
 * @author Andre
 */
public class Partition {
	private final File disk;
	private final int index;
	private PartitionType type;
	private int typeId;
	private long firstSector;
	private int sizeInSectors;
	private boolean isLogicalPartition;
	
	public Partition(int id, File disk) {
		this.index = id;
		this.disk = disk;
	}

	public void fromMBR(byte[] entry, int offset) {
		this.typeId = entry[offset + 0x04] & 0xFF;
		type = PartitionType.fromByteId(typeId);
		if (this.typeId == 0) return;
		
		int sectors = Numbers.byteArrayToInt(entry, offset + 0x0C);
		this.sizeInSectors = sectors;
		
		int start = Numbers.byteArrayToInt(entry, offset + 0x08);
		this.firstSector = start;
	}
	
	public void fromEBR(long ebrLBA, byte[] entry, int offset) {
		fromMBR(entry, offset);
		if (this.typeId == 0) return;
		
		this.isLogicalPartition = true;
		this.firstSector += ebrLBA;
	}
	
	public int getIndex() {
		return index;
	}
	
	public File getDisk() {
		return disk;
	}
	
	public long getFirstSector() {
		return firstSector;
	}
	
	public PartitionType getType() {
		return type;
	}
	
	public int getTypeId() {
		return typeId;
	}
	
	public boolean isLogical() {
		return isLogicalPartition;
	}
	
	public boolean isExtended() {
		return type.isExtended();
	}
	
	public String getSizeString() {
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
		return type.description;
	}
	
	@Override
	public String toString() {
		var typeStr = getTypeDescription();
		var sizeStr = getSizeString();
		
		return String.format("[%d] 0x%02X='%s' : %s : 0x%02X", index, typeId, typeStr, sizeStr, firstSector);
	}
}
