package com.andre.pasme.transpiler;

/**
 * A Util Pair class.
 * <br>
 * <br>Last edit: 30/04/2023
 * @author Andre
 */
public class Pair<K, V> {
	public K key;
	public V value;

	public Pair(){	}
	
	public Pair(K k, V v){
		key = k;
		value = v;
	}
}
