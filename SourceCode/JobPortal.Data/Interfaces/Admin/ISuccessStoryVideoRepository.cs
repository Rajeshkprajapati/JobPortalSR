﻿using JobPortal.Model.DataViewModel.Admin.SuccessStory;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Admin
{
  public interface ISuccessStoryVideoRepository
    {
        DataTable GetSuccessStoryVid();
        bool InsertUpdateSuccessStoryVid(SuccessStoryVideoViewModel successStory);
        bool DeleteSuccessStoryVid(string id, string deletedBy);
    }
}
