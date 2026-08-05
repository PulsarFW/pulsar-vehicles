AddEventHandler("Vehicles:Client:StartUp", function()
	plsr.Callbacks:RegisterClientCallback("Vehicles:UseCamberController", function(data, cb)
		if
			VEHICLE_INSIDE
			and DoesEntityExist(VEHICLE_INSIDE)
			and IsEntityAVehicle(VEHICLE_INSIDE)
			and GetPedInVehicleSeat(VEHICLE_INSIDE, -1) == PlayerPedId()
		then
			if plsr.Police:IsPdCar(VEHICLE_INSIDE) or plsr.Police:IsEMSCar(VEHICLE_INSIDE) then
				plsr.Notification:Error("How About No")
				cb(false)
				return
			end

			local vehModel = GetEntityModel(VEHICLE_INSIDE)

			if
				IsThisModelABike(vehModel)
				or IsThisModelABicycle(vehModel)
				or IsThisModelAPlane(vehModel)
				or IsThisModelAHeli(vehModel)
				or IsThisModelABoat(vehModel)
			then
				cb(false)
				return
			end

			plsr.Progress:Progress({
				name = "vehicle_camber_controller",
				duration = 5000,
				label = "Plugging In Controller",
				useWhileDead = false,
				canCancel = true,
				controlDisables = {
					disableMovement = true,
					disableCarMovement = true,
					disableMouse = false,
					disableCombat = false,
				},
				animation = {
					anim = "mechanic2",
				},
			}, function(cancelled)
				if not cancelled and VEHICLE_INSIDE then
					cb(VehToNet(VEHICLE_INSIDE))
				else
					cb(false)
				end
			end)
		else
			cb(false)
		end
	end)
end)
