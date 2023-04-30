package com.andre.pasme;

public class CLIException extends RuntimeException {
	public CLIException(){}
	public CLIException(String str) { super(str); }
	public CLIException(Throwable cause) { super(cause); }
}