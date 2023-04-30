package com.andre.pasme;

public class AssemblerException extends RuntimeException {
	public AssemblerException(){}
	public AssemblerException(String str) { super(str); }
	public AssemblerException(Throwable cause) { super(cause); }
}