package com.andre.devtoolkit;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardWatchEventKinds;
import java.nio.file.WatchEvent;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author Andre
 */
public class DiskSyncService {
	boolean diskMounted;
	long lastTimeDiskMounted;
	String diskFilePath;
	Path srcPath;
	Path diskPath;
	
	public DiskSyncService(String diskFile, String srcPath, String diskPath) {
		try {
			this.diskFilePath = new File(diskFile).getCanonicalPath();
			this.srcPath = Path.of(srcPath);
			this.diskPath = Path.of(diskPath);
		} catch (IOException ex) {
			throw new RuntimeException(ex);
		}
	}
	
	public void run() {
		try {
			var watcher = FileSystems.getDefault().newWatchService();
			srcPath.register(watcher,
					StandardWatchEventKinds.ENTRY_CREATE,
					StandardWatchEventKinds.ENTRY_MODIFY);
			
			new Thread(() -> {
				while (true) {
					try {
						Thread.sleep(1000);
					} catch (InterruptedException ex) {}
					
					if (diskMounted) {
						if (System.currentTimeMillis() - lastTimeDiskMounted > 5000) {
							unmountDisk();
						}
					}
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
						System.out.println("[!] Could'nt mount.");
					}
					
					try {
						Executor.execSilently("cmd", "/c", "copy", srcFile.toString(), dstFile.toString());
						System.out.println("    Copied.");
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
				System.out.println("[!] Disk unmounting failed.");
				throw new CLIException("Diskpart failed with code " + returnCode);
			}
			System.out.println("    Disk unmounted.");
		} catch(Exception ex) {
			throw new RuntimeException(ex);
		}
	}
}
