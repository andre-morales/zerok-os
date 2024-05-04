package com.andre.devtoolkit;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardWatchEventKinds;
import java.nio.file.WatchEvent;

/**
 *
 * @author Andre
 */
public class DiskSyncService {
	final int UNMOUNTING_DELAY = 1000;
	
	boolean diskMounted;
	long lastTimeDiskMounted;
	String diskFilePath;
	Path srcPath;
	Path diskPath;
	
	public DiskSyncService(File diskFile, String srcPath, String diskPath) {
		try {
			this.diskFilePath = diskFile.getCanonicalPath();
			this.srcPath = Path.of(srcPath);
			this.diskPath = Path.of(diskPath);
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}
	
	public void run() {
		System.out.println("-- Disk Syncing Utility --");
		if (!Executor.hasElevatedPrivleges()) {
			System.out.println("[!] WARNING: No elevated privleges. Mounting might fail.");
		}
		
		try {
			var watcher = FileSystems.getDefault().newWatchService();
			srcPath.register(watcher,
					StandardWatchEventKinds.ENTRY_CREATE,
					StandardWatchEventKinds.ENTRY_MODIFY);
			
			new Thread(() -> {
				while (true) {
					try {
						Thread.sleep(1000);
					
						if (diskMounted) {
							if (System.currentTimeMillis() - lastTimeDiskMounted > UNMOUNTING_DELAY) {
								unmountDisk();
							}
						}
					} catch (Exception ex) {}
				}
			}).start();
			
			while (true) {
				var wkey = watcher.take();
				
				for (var ev : wkey.pollEvents()) {
					var kind = ev.kind();
					if (kind == StandardWatchEventKinds.OVERFLOW) continue;
					
					var event = (WatchEvent<Path>)ev;
					var pathAltered = event.context();
					
					var srcFile = srcPath.resolve(pathAltered);
					System.out.println("Modified: " + srcFile);
					
					var dstFile = diskPath.resolve(pathAltered);
					System.out.println("Copying to: " + dstFile);
					
					try {
						mountDisk();
						System.out.println("    Mounted.");
					} catch (Exception ex) {
						System.out.println("[.] Could'nt mount.");
					}
					
					try {
						Executor.execSilently("cmd", "/c", "copy", srcFile.toString(), dstFile.toString());
						System.out.println("    Copied.");
						diskMounted = true;
					} catch (Exception ex) {
						System.out.println("[!] Copy failed.");
					}
				}
				
				if(!wkey.reset()) return;
			}
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}
	
	synchronized void mountDisk() {
		diskMounted = true;
		lastTimeDiskMounted = System.currentTimeMillis();
			
		try {
			
			var script = Files.createTempFile(null, ".dps");
			var scriptFile = script.toFile();
			
			try (var writer = new FileWriter(scriptFile)) {
				writer.write("select vdisk file=\"" + diskFilePath + "\"\n");
				writer.write("attach vdisk");
			}

			int returnCode = Executor.execSilently("diskpart", "/s", script.toString());
			if (returnCode != 0) {
				System.out.println("[!] Disk attach failed.");
				throw new CLIException("Diskpart failed with code " + returnCode);
			}
		} catch(Exception ex) {
			throw new RuntimeException(ex);
		}
	}
	
	synchronized void unmountDisk() {
		try {
			diskMounted = false;
			
			var script = Files.createTempFile(null, ".dps");
			var scriptFile = script.toFile();
			
			try (var writer = new FileWriter(scriptFile)) {
				writer.write("select vdisk file=\"" + diskFilePath + "\"\n");
				writer.write("detach vdisk");
			}

			int returnCode = Executor.execSilently("diskpart", "/s", script.toString());
			if (returnCode != 0) {
				System.out.println("[.] Disk unmounting failed.");
				throw new CLIException("Diskpart failed with code " + returnCode);
			}
			System.out.println("    Disk unmounted.");
		} catch(Exception ex) {
			throw new RuntimeException(ex);
		}
	}
}
