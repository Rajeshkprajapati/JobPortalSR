using JobPortal.Data.DataModel.Shared;
using System;
﻿using JobPortal.Model.DataViewModel.Shared;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace JobPortal.Data.Interfaces.Admin
{
    public interface IManageCityStateRepository
    {
        bool DeleteCity(string citycode,string statecode);
        bool AddCity(CityModel city);
        bool UpdateCity(CityModel city);
        bool InsertStateList(StateViewModel stateViewModel);
        bool UpdateStateList(StateViewModel stateViewModel);
        bool DeleteStateList(StateViewModel stateViewModel);
        bool CheckIfStateCodeExist(string stateCode);
    }
}
