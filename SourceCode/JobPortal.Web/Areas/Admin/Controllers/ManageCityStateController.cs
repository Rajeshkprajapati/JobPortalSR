using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using JobPortal.Business.Interfaces.Admin;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using JobPortal.Utility.ExtendedMethods;
using JobPortal.Utility.Helpers;
using JobPortal.Web.Filters;
using Microsoft.AspNetCore.Mvc;


namespace JobPortal.Web.Areas.Admin.Controllers
{
    [Area("Admin")]
    [Route("[controller]")]
    [HandleExceptionsAttribute]
    [UserAuthentication("Admin")]
    public class ManageCityStateController : Controller
    {
        private readonly IManageCityStateHandler _manageCityStateHandler;
        public ManageCityStateController(IManageCityStateHandler manageCityStateHandler)
        {
            _manageCityStateHandler = manageCityStateHandler;
        }

        //[HttpGet]
        //public IActionResult GetAllCity()
        //{
        //    IList<CityViewModel> list = new List<CityViewModel>();
        //    try
        //    {
        //        ViewBag.AllState = _manageCityStateHandler.GetAllState();
        //        list = _manageCityStateHandler.GetAllCity();
        //    }
        //    catch (DataNotFound ex)
        //    {
        //        Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
        //    }
        //    return View(list);
        //}

        [HttpPost]
        [Route("[action]")]
        public JsonResult AddCity([FromBody]CityViewModel model)
        {
            var msg = true;
            try
            {
                if (!_manageCityStateHandler.AddCity(model))
                {
                    msg = false;
                }

            }catch(Exception ex)
            {
                msg = false;
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
            }
            return Json(new {msg});
        }

        [HttpPost]
        [Route("[action]")]
        public JsonResult UpdateCity([FromBody]CityViewModel model)
        {
            var msg = true;
            try
            {
                _manageCityStateHandler.UpdateCity(model);
            }
            catch (DataNotFound ex)
            {
                msg = false;
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
            }
            return Json(new { msg });
        }

        [HttpGet]
        [Route("[action]")]
        public JsonResult DeleteCity(string citycode,string statecode)
        {
            var msg = true;
            try
            {
                _manageCityStateHandler.DeleteCity(citycode,statecode);
            }
            catch (DataNotFound ex)
            {
                msg = false;
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
            }
            return Json(new {msg});            
        }

        //[HttpGet]
        //[Route("[action]")]
        //public IActionResult StateList()
        //{
        //    List<StateViewModel> list = new List<StateViewModel>();
        //    try
        //    {
        //        list = _manageCityStateHandler.GetStateList("IN");
        //        ViewBag.AllCountry = _manageCityStateHandler.GetCountryList();
        //    }
        //    catch (DataNotFound ex)
        //    {
        //        Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
        //        ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
        //    }
        //    return View(list);
        //   }
        [HttpPost]
        [Route("[action]")]
        public IActionResult InsertState([FromBody]StateViewModel stateModel)
        {
            //var user = HttpContext.Session.Get<StateViewModel>(Constants.SessionKeyUserInfo);
            try
            {
                var result = _manageCityStateHandler.InsertStateList(stateModel);
                return Json("Data Inserted");
            }
            catch (DataNotUpdatedException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));                
            }
            catch (UserAlreadyExists ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
                return Json(ex.Message);
            }
            return Json("Unable to do this action");
        }

        [HttpPost]
        [Route("[action]")]
        public IActionResult UpdateState([FromBody]StateViewModel stateModel)
        {
            //var user = HttpContext.Session.Get<StateViewModel>(Constants.SessionKeyUserInfo);
            try
            {
                var result = _manageCityStateHandler.UpdateStateList(stateModel);
                return Json("Data updated");
            }
            catch (DataNotUpdatedException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return Json("Unable to do this action");
        }

        [HttpPost]
        [Route("[action]")]
        public IActionResult DeleteState([FromBody]StateViewModel stateModel)
        {
            //var user = HttpContext.Session.Get<StateViewModel>(Constants.SessionKeyUserInfo);
            try
            {
                var result = _manageCityStateHandler.DeleteStateList(stateModel);
                return Json("Data deleted");
            }
            catch (DataNotUpdatedException ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return Json("Unable to do this action");
        }

        [HttpGet]
        [Route("[action]")]
        public PartialViewResult StateList()
        {
            List<StateViewModel> list = new List<StateViewModel>();
            try
            {
                list = _manageCityStateHandler.GetStateList("IN");
                ViewBag.AllCountry = _manageCityStateHandler.GetCountryList();
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
                ModelState.AddModelError("ErrorMessage", string.Format("{0}", ex.Message));
            }
            return PartialView("StateList", list);
        }

        [HttpGet]
        [Route("[action]")]
        public PartialViewResult GetAllCity()
        {
            IList<CityViewModel> list = new List<CityViewModel>();
            try
            {
                ViewBag.AllState = _manageCityStateHandler.GetAllState();
                list = _manageCityStateHandler.GetAllCity();
            }
            catch (DataNotFound ex)
            {
                Logger.Logger.WriteLog(Logger.Logtype.Error, ex.Message, 0, typeof(ManageCityStateController), ex);
            }
            return PartialView("GetAllCity", list);
        }
    }
}