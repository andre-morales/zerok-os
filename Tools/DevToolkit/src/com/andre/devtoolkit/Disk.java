package com.andre.devtoolkit;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.util.ArrayList;
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
	
	public List<DiskPartition> listPartitions() {
		var partitions = new ArrayList<DiskPartition>();
			
		// Get MBR partition list
		var mbrBytes = Burner.readBytes(diskFile, 0x1BE, 0x40);
		
		// Itreate over 4 initial partitions
		for (int i = 0; i < 4; i++) {
			var part = new DiskPartition(i, diskFile, mbrBytes, i * 16);
			if (part.getType().typeId == 0) continue;
			
			partitions.add(part);
			
			if (part.getType().isExtended()) {
				var logicalParts = listExtendedPartitions(part);
				partitions.addAll(logicalParts);
			}
		}
		
		return partitions;
	}
	
	private List<DiskPartition> listExtendedPartitions(DiskPartition extendPart) {
		return List.of();
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
}
