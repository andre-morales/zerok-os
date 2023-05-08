package com.andre.pasme.transpiler;

/**
 *
 * @author Andre
 */
public class Line {
	public String content;
	public int number;

	public Line(String content, int number) {
		this.content = content;
		this.number = number;
	}
	
	public Line(String content, Line source) {
		this.content = content;
		this.number = source.number;
	}
}
