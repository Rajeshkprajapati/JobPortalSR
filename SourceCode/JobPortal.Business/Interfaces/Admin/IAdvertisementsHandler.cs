using JobPortal.Model.DataViewModel.Admin.Advertisements;
using System;
using System.Collections.Generic;
using System.Text;

namespace JobPortal.Business.Interfaces.Admin
{
    public interface IAdvertisementsHandler
    {
        IEnumerable<AdvertisementsViewModel> GetAllData(int section=0);
        bool AddAds(AdvertisementsViewModel model);
        bool UpdateAds(AdvertisementsViewModel model,int userid);
        bool DeleteAds(int adId);
    }
}
