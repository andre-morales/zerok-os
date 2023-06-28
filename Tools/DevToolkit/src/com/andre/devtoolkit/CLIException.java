package com.andre.devtoolkit;

/**
 * Thrown whenever the CLI receives malformed request. Could be because of
 * missing parameters, bad parameters or missing extensions.
 * <br>
 * <br> Last edit: 30/04/2023
 * @author André Morales
 */
public class CLIException extends RuntimeException {
	public CLIException(){}
	public CLIException(String str) { super(str); }
	public CLIException(Throwable cause) { super(cause); }
}