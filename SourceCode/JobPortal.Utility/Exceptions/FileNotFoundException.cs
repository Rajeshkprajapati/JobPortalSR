﻿using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Utility.Exceptions
{
    public class FileNotFoundException:ApplicationException
    {
        public FileNotFoundException(string message) : base(message)
        {

        }

        public FileNotFoundException(string message, Exception exception) : base(message, exception)
        {

        }
    }
}
