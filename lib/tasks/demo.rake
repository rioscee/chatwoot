namespace :demo do
  desc 'Poblar el CRM con datos de prueba masivos para demostraciones (WhatsApp, Instagram, Facebook Messenger, Telegram, Web Chat y Campañas)'
  task poblar: :environment do
    puts '🚀 Iniciando la carga masiva de datos multicanal de prueba para la Demo...'

    account = Account.first
    unless account
      puts '❌ No se encontró ninguna cuenta. Por favor abre la app primero para inicializar la cuenta.'
      next
    end

    main_user = account.users.first

    # 1. Crear Agentes de Ejemplo (Vendedores)
    sample_agents_data = [
      { name: 'Laura Ramírez', email: 'laura.ramirez@ejemplo.com' },
      { name: 'Pedro Castro', email: 'pedro.castro@ejemplo.com' }
    ]

    sample_agents = sample_agents_data.map do |agent_info|
      u = User.find_or_create_by!(email: agent_info[:email]) do |usr|
        usr.name = agent_info[:name]
        usr.password = 'Password1!'
        usr.password_confirmation = 'Password1!'
      end
      AccountUser.find_or_create_by!(account_id: account.id, user_id: u.id) do |au|
        au.role = :agent
      end
      u
    end
    all_agents = [main_user, sample_agents].flatten.compact
    puts "✅ Agentes de prueba creados (#{all_agents.map(&:name).join(', ')})."

    # 2. Asegurar que existe el Embudo de Ventas y sus etapas
    pipeline = account.pipelines.first
    unless pipeline
      pipeline = account.pipelines.create!(name: 'Embudo de Ventas Principal')
      default_stages = [
        { name: 'Prospecto', position: 1 },
        { name: 'Contacto Realizado', position: 2 },
        { name: 'Demostración Programada', position: 3 },
        { name: 'Propuesta Enviada', position: 4 },
        { name: 'Negociación Iniciada', position: 5 }
      ]
      default_stages.each do |stg|
        pipeline.pipeline_stages.create!(stg.merge(account_id: account.id))
      end
    end

    stages = pipeline.pipeline_stages.order(:position).to_a

    # 3. Crear Canales Multicanal (WhatsApp, Instagram, Facebook, Telegram, Web Support)
    # WhatsApp
    channel_wa = Channel::Whatsapp.find_by(account_id: account.id)
    unless channel_wa
      channel_wa = Channel::Whatsapp.new(
        account_id: account.id,
        phone_number: '+15551234567',
        provider: 'whatsapp_cloud',
        provider_config: { 'api_key' => 'mock_key', 'phone_number_id' => '123456' }
      )
      channel_wa.save!(validate: false)
    end
    inbox_wa = account.inboxes.find_or_create_by!(name: 'WhatsApp Ventas', channel: channel_wa)

    # Instagram
    channel_ig = Channel::Instagram.find_by(account_id: account.id)
    unless channel_ig
      channel_ig = Channel::Instagram.new(
        account_id: account.id,
        instagram_id: 'mock_ig_id',
        access_token: 'mock_token',
        expires_at: 1.year.from_now
      )
      channel_ig.save!(validate: false)
    end
    inbox_ig = account.inboxes.find_or_create_by!(name: 'Instagram DM', channel: channel_ig)

    # Facebook Messenger
    channel_fb = Channel::FacebookPage.find_by(account_id: account.id)
    unless channel_fb
      channel_fb = Channel::FacebookPage.new(
        account_id: account.id,
        page_id: 'mock_fb_page_id',
        page_access_token: 'mock_token',
        user_access_token: 'mock_token'
      )
      channel_fb.save!(validate: false)
    end
    inbox_fb = account.inboxes.find_or_create_by!(name: 'Facebook Messenger', channel: channel_fb)

    # Telegram
    channel_tg = Channel::Telegram.find_by(account_id: account.id)
    unless channel_tg
      channel_tg = Channel::Telegram.new(
        account_id: account.id,
        bot_name: 'DemoBot',
        bot_token: '123456789:ABCdefGHIjklMNOpqrsTUVwxyZ'
      )
      channel_tg.save!(validate: false)
    end
    inbox_tg = account.inboxes.find_or_create_by!(name: 'Telegram Soporte', channel: channel_tg)

    # Web Chat (Web Support)
    inbox_web = account.inboxes.find_by(channel_type: 'Channel::WebWidget') || account.inboxes.first
    inbox_web.update!(name: 'Web Support') if inbox_web && inbox_web.name != 'Web Support'

    # Asignar a todos los usuarios a todas las bandejas creadas
    account.inboxes.each do |inb|
      all_agents.each do |ag|
        InboxMember.find_or_create_by!(inbox_id: inb.id, user_id: ag.id)
      end
    end

    # 4. Lista Masiva de 18 Contactos y Conversaciones Multicanal
    sample_conversations_data = [
      # WhatsApp (4)
      { name: 'María García', email: 'maria.garcia@ejemplo.com', phone: '+51987654321', inbox: inbox_wa, assignee: main_user, msg: '¡Hola! Quisiera información sobre los planes de suscripción para mi negocio por WhatsApp.', stage: stages[0], deal_name: 'Plan Anual Pizzería Bella', value: 1200 },
      { name: 'Diego Morales', email: 'diego.morales@ejemplo.com', phone: '+51934567890', inbox: inbox_wa, assignee: main_user, msg: '¿Cuáles son los métodos de pago disponibles? Me escribes al WhatsApp porfa.', stage: stages[1], deal_name: 'Consultoría Multicanal Restaurante', value: 980 },
      { name: 'Gonzalo Herrera', email: 'gonzalo.herrera@ejemplo.com', phone: '+51995678901', inbox: inbox_wa, assignee: sample_agents[0], msg: 'Hola equipo, requiero integrar 3 líneas de WhatsApp para mi call center.', stage: stages[2], deal_name: 'Integración 3 Líneas WA', value: 2400 },
      { name: 'Patricia Alarcón', email: 'patricia.alarcon@ejemplo.com', phone: '+51996789012', inbox: inbox_wa, assignee: nil, msg: 'Buenas tardes, envié el comprobante de pago por WhatsApp para activar mi plan.', stage: stages[4], deal_name: 'Activación Cuenta PRO', value: 1800 },

      # Instagram DM (4)
      { name: 'Carlos Mendoza', email: 'carlos.mendoza@ejemplo.com', phone: '+51912345678', inbox: inbox_ig, assignee: main_user, msg: 'Buenas tardes, ¿tienen disponibilidad para agendar una demostración por Instagram?', stage: stages[0], deal_name: 'Servicio CRM Barbería Club', value: 450 },
      { name: 'Valentina Torres', email: 'valentina.torres@ejemplo.com', phone: '+51945678901', inbox: inbox_ig, assignee: sample_agents[0], msg: 'Hola, vi su historia de Instagram y me interesa instalar el sistema en mi tienda.', stage: stages[2], deal_name: 'Demostración Plataforma VIP', value: 1500 },
      { name: 'Sebastián Paredes', email: 'sebastian.paredes@ejemplo.com', phone: '+51997890123', inbox: inbox_ig, assignee: sample_agents[1], msg: '¡Hola! Me encantó la plantilla de WhatsApp que publicaron en Reels.', stage: stages[1], deal_name: 'Licencia Plantillas Reels', value: 350 },
      { name: 'Valeria Castro', email: 'valeria.castro@ejemplo.com', phone: '+51998901234', inbox: inbox_ig, assignee: nil, msg: 'Hola, ¿pueden responder el DM? Quiero comprar la licencia para mi marca de ropa.', stage: stages[3], deal_name: 'Licencia Marca de Ropa', value: 1100 },

      # Facebook Messenger (4)
      { name: 'Ana Lucía Rodríguez', email: 'ana.rodriguez@ejemplo.com', phone: '+51923456789', inbox: inbox_fb, assignee: main_user, msg: 'Hola, me gustaría saber si el CRM se puede conectar con mi fanpage de Facebook Messenger.', stage: stages[1], deal_name: 'Implementación Tienda Calzado', value: 850 },
      { name: 'Elena Morales', email: 'elena.morales@ejemplo.com', phone: '+51992345678', inbox: inbox_fb, assignee: main_user, msg: 'Hola, quisiera cotizar la plataforma CRM para 3 sucursales de mi restaurante.', stage: stages[3], deal_name: 'Licencia 5 Vendedores', value: 1350 },
      { name: 'Roberto Sánchez', email: 'roberto.sanchez@ejemplo.com', phone: '+51991234567', inbox: inbox_fb, assignee: nil, msg: '¡Buenas! Me comunico por Facebook Messenger. ¿Tienen delivery gratis para Lima Metropolitana?', stage: stages[2], deal_name: 'Cotización 3 Sucursales', value: 2100 },
      { name: 'Javier Ramos', email: 'javier.ramos@ejemplo.com', phone: '+51993456789', inbox: inbox_fb, assignee: sample_agents[1], msg: 'Buenas noches, ¿aceptan tarjetas de crédito y facturación electrónica?', stage: stages[3], deal_name: 'Paquete Empresarial Facturación', value: 2800 },

      # Telegram (3)
      { name: 'Lucía Méndez', email: 'lucia.mendez@ejemplo.com', phone: '+51994567890', inbox: inbox_tg, assignee: sample_agents[0], msg: 'Hola equipo, me uní a su canal de Telegram y quiero contratar el servicio de chatbots.', stage: stages[4], deal_name: 'Cierre de Contrato Anual', value: 3400 },
      { name: 'Gabriel Núñez', email: 'gabriel.nunez@ejemplo.com', phone: '+51999012345', inbox: inbox_tg, assignee: nil, msg: 'Hola, ¿tienen bot automatizado para responder preguntas frecuentes en Telegram?', stage: stages[0], deal_name: 'Bot Telegram Automático', value: 650 },
      { name: 'Andrea Benítez', email: 'andrea.benitez@ejemplo.com', phone: '+51990123456', inbox: inbox_tg, assignee: sample_agents[1], msg: 'Buenas noches, ¿cómo puedo vincular Telegram con las respuestas automáticas?', stage: stages[1], deal_name: 'Configuración Automatización TG', value: 500 },

      # Web Chat Widget (3)
      { name: 'Fernando Gómez', email: 'fernando.gomez@ejemplo.com', phone: '+51956789012', inbox: inbox_web, assignee: nil, msg: 'Hola desde el chat web, necesito ayuda con la instalación de la widget en Shopify.', stage: stages[0], deal_name: 'Instalación Widget Shopify', value: 400 },
      { name: 'Sofía Vargas', email: 'sofia.vargas@ejemplo.com', phone: '+51967890123', inbox: inbox_web, assignee: sample_agents[0], msg: 'Hola, estoy navegando en su página web y quiero solicitar una llamada comercial.', stage: stages[2], deal_name: 'Asesoría Comercial Web', value: 1600 },
      { name: 'Jorge Silva', email: 'jorge.silva@ejemplo.com', phone: '+51978901234', inbox: inbox_web, assignee: sample_agents[1], msg: 'Buenas tardes, ¿tienen documentación en español para desarrolladores?', stage: stages[3], deal_name: 'Integración API Personalizada', value: 2900 }
    ]

    sample_conversations_data.each_with_index do |data, idx|
      contact = account.contacts.find_or_create_by!(email: data[:email]) do |c|
        c.name = data[:name]
        c.phone_number = data[:phone]
      end

      target_inbox = data[:inbox]
      source_id = case target_inbox.channel_type
                  when 'Channel::Whatsapp'
                    contact.phone_number.to_s.gsub(/[^0-9]/, '')
                  else
                    "src_#{contact.id}_#{target_inbox.id}"
                  end

      contact_inbox = ::ContactInbox.find_or_create_by!(contact_id: contact.id, inbox_id: target_inbox.id) do |ci|
        ci.source_id = source_id
      end

      conversation = account.conversations.find_or_create_by!(contact_id: contact.id, inbox_id: target_inbox.id) do |conv|
        conv.contact_inbox_id = contact_inbox.id
        conv.status = 'open'
        conv.assignee_id = data[:assignee]&.id
      end

      if conversation.messages.empty?
        conversation.messages.create!(
          account_id: account.id,
          inbox_id: target_inbox.id,
          content: data[:msg],
          message_type: :incoming,
          sender: contact
        )
      end

      if data[:stage]
        Deal.find_or_create_by!(name: data[:deal_name], account_id: account.id) do |deal|
          deal.value = data[:value]
          deal.pipeline_stage_id = data[:stage].id
          deal.contact_id = contact.id
          deal.position = idx + 1
          deal.status = 'open'
        end
      end
    end

    # 5. Crear Campañas de Ejemplo para Demostración
    campaign_web = account.campaigns.find_or_create_by!(title: 'Bienvenida Chat Web') do |cmp|
      cmp.description = 'Mensaje emergente automático de salutación a los visitantes de la web tras 5 segundos.'
      cmp.message = '¡Hola! 👋 Bienvenido a nuestro sitio web. ¿En qué podemos ayudarte hoy?'
      cmp.inbox_id = inbox_web.id
      cmp.campaign_type = 'ongoing'
      cmp.campaign_status = 'active'
      cmp.trigger_rules = { 'time_on_page' => 5, 'url' => 'https://ejemplo.com' }
      cmp.sender_id = main_user.id
    end

    campaign_wa = account.campaigns.find_or_create_by!(title: 'Lanzamiento Promo Cierre de Mes') do |cmp|
      cmp.description = 'Campaña masiva enviada a lista de prospectos interesados por WhatsApp.'
      cmp.message = '¡Hola! Tenemos un descuento especial del 20% en licencias CRM solo por hoy. ¿Deseas más información?'
      cmp.inbox_id = inbox_wa.id
      cmp.campaign_type = 'one_off'
      cmp.campaign_status = 'active'
      cmp.scheduled_at = Time.now.utc
      cmp.sender_id = main_user.id
    end

    puts "✅ Campañas de prueba creadas ('#{campaign_web.title}' y '#{campaign_wa.title}')."
    puts "🎉 ¡El CRM ahora está completamente poblado con bandejas renombradas a 'Web Support' y campañas activas!"
  end

  desc 'Limpiar todos los datos de prueba dejando la instalación 100% como nueva para un cliente'
  task limpiar: :environment do
    puts '🧹 Limpiando datos de prueba del CRM...'

    account = Account.first
    unless account
      puts '❌ No se encontró ninguna cuenta.'
      next
    end

    # 1. Borrar Campañas de prueba
    account.campaigns.destroy_all
    puts "🗑️ Se eliminaron las campañas de prueba."

    # 2. Borrar todos los tratos (Deals)
    deals_count = Deal.where(account_id: account.id).count
    Deal.where(account_id: account.id).destroy_all
    puts "🗑️ Se eliminaron #{deals_count} tratos del Kanban."

    # 3. Borrar mensajes y conversaciones
    conv_count = account.conversations.count
    account.conversations.destroy_all
    puts "🗑️ Se eliminaron #{conv_count} conversaciones de prueba."

    # 4. Borrar contactos de prueba
    contacts_count = account.contacts.count
    account.contacts.destroy_all
    puts "🗑️ Se eliminaron #{contacts_count} contactos."

    # 5. Borrar bandejas multicanal de prueba
    inboxes_count = account.inboxes.where.not(channel_type: 'Channel::WebWidget').count
    account.inboxes.where.not(channel_type: 'Channel::WebWidget').destroy_all
    puts "🗑️ Se eliminaron #{inboxes_count} bandejas multicanal de prueba."

    # 6. Borrar agentes de prueba
    sample_emails = ['laura.ramirez@ejemplo.com', 'pedro.castro@ejemplo.com']
    User.where(email: sample_emails).destroy_all
    puts '🗑️ Se eliminaron los agentes de prueba.'

    puts '✨ ¡El CRM ha sido limpiado por completo! Está listo como nuevo para entregárselo a tu cliente.'
  end
end
