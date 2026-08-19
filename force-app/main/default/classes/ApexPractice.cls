public with sharing class ApexPractice {
    /*public  void reverseString(string input) {
        list<string> splitString=input.split(' ');
        list<string> endResult= new list<string>();
        system.debug('split: ' + splitString);
        for(integer i=splitString.size()-1;i>=0;i--){
            endResult.add(splitString[i]);
            
        }
        system.debug('endResult: ' + endResult);

    }
    public void testReverseString() {
   reverseString('Hello World');
    }
}
    ApexPractice apx = new ApexPractice();
apx.testReverseString();*/
public void countFrequent(List<integer> nums, Integer K){
    Map<Integer, Integer> freq = new Map<Integer, Integer>();
    for (Integer n : nums) {
        Integer currentCount = freq.containsKey(n) ? freq.get(n) : 0;
            freq.put(n, currentCount + 1);
    }
    List<Integer> result = new List<Integer>();
    for (Integer n : freq.keySet()) {
        if (freq.get(n) >= K) {
            result.add(n);
        }
    }
    system.debug('Frequent Elements: ' + result + ' with frequency >= ' + K);
}
}ApexPractice apx = new ApexPractice();
apx.countFrequent(new List<Integer>{1, 2, 2, 3, 3, 3}, 3);
