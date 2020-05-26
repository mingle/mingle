class T1
  def initialize()
  end
  
  def xmethod_missing(m, *args, &block)  
    puts(args.join("\", \""))
  end   
  
  def wait(timeout) 
    puts "here"
    total = 0;
    interval = 0.2;
    
    if !block_given?
      puts "no block"
      sleep(timeout)
      return
    end
    
    while (total < timeout)
      sleep(interval);
      total += interval;
      begin 
        return if yield
      rescue Exception=>e 
        puts e
      end
    end          
  end
  
end

t1 = T1.new()
t1.wait(10000){
  true
}

 