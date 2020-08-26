using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class UnSpecifiedFileFormatException:ApplicationException
    {
        public UnSpecifiedFileFormatException(string message) : base(message)
        {

        }

        public UnSpecifiedFileFormatException(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
