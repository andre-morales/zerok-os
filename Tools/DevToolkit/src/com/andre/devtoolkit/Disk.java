package com.andre.devtoolkit;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 *
 * @author Andre
 */
public class Disk {
	private final File diskFile;
	
	public Disk(File file) {
		this.diskFile = file;
	}
	
	public List<Partition> listPartitions() {
		var partitions = new ArrayList<Partition>();
		partitions.addAll(Collections.nCopies(5, null));
		
		// Get MBR partition list
		var mbrBytes = Burner.readBytes(diskFile, 0x1BE, 0x40);
		
		// Itreate over 4 initial partitions
		for (int i = 0; i < 4; i++) {
			int index = i + 1;
			var part = new Partition(index, diskFile);
			part.fromMBR(mbrBytes, i * 16);
			if (part.getType().typeId == 0) continue;
			
			partitions.set(index, part);

			if (part.getType().isExtended()) {
				var logicalParts = listLogicalPartitions(part, partitions.size());
				partitions.addAll(logicalParts);
			}
		}
		
		return partitions;
	}
	
	/** List logical partitions on the disk. */
	private List<Partition> listLogicalPartitions(Partition extendedPart, int counter) {
		var partitions = new ArrayList<Partition>();	
		
		long extendedPartitionLBA = extendedPart.getFirstSector();		
		long ebrSectorLBA = extendedPartitionLBA;
		
		for ( ; ; counter++) {
			byte[] ebrEntries = Burner.readBytes(diskFile, ebrSectorLBA * 512 + 0x1BE, 0x20);
			
			// First entry, should always be a logical partition
			var part = new Partition(counter, diskFile);
			part.fromEBR(ebrSectorLBA, ebrEntries, 0);
			
			// If there is no first entry, quit
			if (part.getTypeId() == 0) break;
			
			partitions.add(part);

			// Second entry, should either be empty or point to another EBR
			var chainPart = new Partition(counter, diskFile);
			chainPart.fromEBR(0, ebrEntries, 16);
			
			// If there is no second entry, quit
			if (chainPart.getTypeId() == 0) break;
			
			ebrSectorLBA = extendedPartitionLBA + chainPart.getFirstSector();
		}

		return partitions;
	}
	
	public DiskSyncService createSyncService(String srcPath, String diskPath) {
		return new DiskSyncService(diskFile, srcPath, diskPath);
	}
	
	public void mount() {
		try {
			var absDiskPath = diskFile.getCanonicalPath();
			
			// Create temporary diskpart script to mount the disk file
			var script = Files.createTempFile(null, ".dps");
			try (var writer = new FileWriter(script.toFile())) {
				writer.write("select vdisk file=\"" + absDiskPath + "\"\n");
				writer.write("attach vdisk");
			}
			
			// Execute diskpart with script argument
			int returnCode = Executor.execSilently("diskpart", "/s", script.toString());
			if (returnCode != 0) throw new CLIException("Diskpart failed with code " + returnCode);
		} catch(IOException ex) {
			throw new RuntimeException(ex);
		}
	}
	
	public void unmount() {
		try {
			var absDiskPath = diskFile.getCanonicalPath();
			
			// Create temporary diskpart script to unmount the disk file
			var script = Files.createTempFile(null, ".dps");
			try (var writer = new FileWriter(script.toFile())) {
				writer.write("select vdisk file=\"" + absDiskPath + "\"\n");
				writer.write("detach vdisk");
			}
			
			// Execute diskpart with script argument
			int returnCode = Executor.execSilently("diskpart", "/s", script.toString());
			if (returnCode != 0) throw new CLIException("Diskpart failed with code " + returnCode);
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}

	public byte[] readSector(long sector) {
		return Burner.readBytes(diskFile, sector * 512, 512);
	}
}
