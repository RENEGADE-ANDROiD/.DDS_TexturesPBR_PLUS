class crosswalk
{

bool IsReLiteOn;  // Now this is an instance variable

   Array<string> sbase;
   Array<string> sswap;
   crosswalk init()
   {
       return self;
   }

   string getswap(string s)
   {
       if (self.sbase.Find(s) != self.sbase.size())
       {
           return self.sswap[self.sbase.Find(s)];
       }
       else
       {
           return "NOTFOUND";
       }
   }
}
