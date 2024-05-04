package com.andre.devtoolkit;

import java.io.IOException;
import java.util.prefs.Preferences;

/**
 *
 * @author Andre
 */
public class Executor {
	/**
	 * Runs a program with optional CLI arguments. The program will have all of
	 * its output redirected to stdout. This function only returns when the
	 * process has finished running completely.
	 * 
	 * @param cmd The program command followed by its arguments.
	 * @return The return code of the program.
	 */
	static int exec(String... cmd) {
		try {
			Process proc;
			
			// Build the process and start it. If the program command couldn't be found, throw a dedicated exception.
			try {
				var procBuilder = new ProcessBuilder(cmd);
				procBuilder.redirectErrorStream(true);
				proc = procBuilder.start();
			} catch(IOException e){
				throw new ProgramNotFoundException(e);
			}
			
			// While the program is running, print all its output.
			var input = proc.getInputStream();
			while (proc.isAlive()) {
				int c = input.read();
				if (c > 0) {
					System.out.print((char) c);
				}
			}
			
			// After the program is done running, drain the rest of the output.
			int returnCode = proc.waitFor();
			int c;
			while ((c = input.read()) > 0) {
				System.out.print((char) c);
			}

			return returnCode;
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}
	
	/**
	 * Runs a program with optional CLI arguments. This function only returns when the
	 * process has finished running completely.
	 * 
	 * @param cmd The program command followed by its arguments.
	 * @return The return code of the program.
	 */
	public static int execSilently(String... cmd) {
		try {
			Process proc;
			
			// Build the process and start it. If the program command couldn't be found, throw a dedicated exception.
			try {
				var procBuilder = new ProcessBuilder(cmd);
				procBuilder.redirectErrorStream(true);
				proc = procBuilder.start();
			} catch(IOException e){
				throw new ProgramNotFoundException(e);
			}
						
			// After the program is done running, drain the rest of the output.
			int returnCode = proc.waitFor();
			return returnCode;
		} catch (Exception ex) {
			throw new RuntimeException(ex);
		}
	}
	
	public static boolean hasElevatedPrivleges() {
		var prefs = Preferences.systemRoot();
		
		try {
			prefs.put("dummytest", "test");
			prefs.remove("dummytest");
			prefs.flush();
			return true;
		} catch(Exception ex) {
			return false;
		}
	}
	
}
