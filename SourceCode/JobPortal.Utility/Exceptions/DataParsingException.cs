﻿using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class DataParsingException:ApplicationException
    {
        public DataParsingException(string message) : base(message)
        {

        }

        public DataParsingException(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
