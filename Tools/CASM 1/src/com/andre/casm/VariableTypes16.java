/*
 * 
 * 
 */
package com.andre.casm;

import java.util.HashMap;
import java.util.Map;

/**
 *
 * @author Andre
 */
public class VariableTypes16 {
	public static Map<String, Integer> get(){
		var map = new HashMap<String, Integer>() {};
		map.put("void", 0);
		map.put("byte", 1);
		map.put("bool", 1);
		map.put("char", 1);
		map.put("short", 2);
		map.put("int", 4);
		map.put("long", 8);

		map.put("word", 2);
		map.put("dword", 4);
		map.put("qword", 8);
		
		map.put("void*", 2);
		map.put("byte*", 2);
		map.put("char*", 2);
		return map;
	}
}
