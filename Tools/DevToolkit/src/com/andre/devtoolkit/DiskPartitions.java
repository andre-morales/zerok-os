package com.andre.devtoolkit;

import java.io.File;
import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author Andre
 */
public class DiskPartitions {
	static List<DiskPartition> listPartitions(File disk) {
		var partitions = new ArrayList<DiskPartition>();
			
		// Get MBR partition list
		var mbrBytes = DiskBurner.readBytes(disk, 0x1BE, 0x40);
		
		// Itreate over 4 initial partitions
		for (int i = 0; i < 4; i++) {
			var part = partFromEntry(mbrBytes, i * 16);
			if (part.type == 0) return partitions;
			
			part.id = i;
			
			partitions.add(part);
		}
		
		return partitions;
	}
	
	static DiskPartition partFromEntry(byte[] entry, int offset) {
		var part = new DiskPartition();
		
		byte type = entry[offset + 0x04];
		if (type == 0) return part;
		
		part.type = type;
		
		int sectors = Util.byteArrayToInt(entry, offset + 0x0C);
		part.sizeInSectors = sectors;
		
		int start = Util.byteArrayToInt(entry, offset + 0x08);
		part.startSector = start;
		
		return part;
	}
}
