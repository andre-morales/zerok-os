/*
 * 
 * 
 */
package com.andre.casm;

import java.util.List;

/**
 *
 * @author Andre
 */
public class Str {
	private Str(){}
	
	public static boolean isNullOrEmpty(String str){
		return str == null || str.length() == 0;
	}
	
	public static boolean isQuote(char c){
		return c == '"' || c == '\'';
	}
	
	/** Finds the given search string in the input, and returns
	  * everything after the last character of the search string. */
	public static String remainingAfter(String input, String search){
		int i = input.indexOf(search);
		if (i == -1) {
			return null;
		}

		return input.substring(i + search.length());
	}
	
	/** Returns the input string from the first character until the first
	  * match with the search string.
	  * If the search string is not present on the input, the full input is
	  * returned. */
	public static String untilFirstMatch(String input, String search){
		var i = input.indexOf(search);
		if(i == -1) return input;
		return input.substring(0, i);
	}
	
	/** Returns the input string from the beginning index until the first
	  * match with the search string.
	  * If the search string is not present on the input, the input string is
	  * returned starting from the index. */
	public static String untilFirstMatch(String input, int fromIndex, String search){
		var i = input.indexOf(search, fromIndex);
		if(i == -1) return input.substring(fromIndex);
		return input.substring(fromIndex, i);
	}
	
	/** Returns the input string from the beginning index until the first
	  * match of the provided searches.
	  * If none of the search strings are present on the input, the input string is
	  * returned starting from the index. */
	public static String untilFirstMatch(String input, int fromIndex, String... searches){
		int index = Integer.MAX_VALUE;
		for(var str : searches){
			var i = input.indexOf(str, fromIndex);
			if(i != -1 && i < index) index = i;
		}
		
		if(index == Integer.MAX_VALUE) return input.substring(fromIndex);
		return input.substring(fromIndex, index);
	}
}
