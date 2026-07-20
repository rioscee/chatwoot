namespace :demo do
  desc 'Poblar el CRM con datos de prueba realistas para demostraciones (Contactos, Conversaciones Multicanal y Tratos Kanban)'
  task poblar: :environment do
    puts '🚀 Iniciando la carga de datos de prueba multicanal para la Demo...'

    account = Account.first
    unless account
      puts '❌ No se encontró ninguna cuenta. Por favor abre la app primero para inicializar la cuenta.'
      next
    end

    user = account.users.first

    # 1. Asegurar que existe el Embudo de Ventas y sus etapas
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
    if stages.empty?
      puts '❌ El embudo no tiene etapas creadas.'
      next
    end

    # 2. Crear Contactos de Prueba
    sample_contacts_data = [
      { name: 'María García', email: 'maria.garcia@ejemplo.com', phone_number: '+51987654321' },
      { name: 'Carlos Mendoza', email: 'carlos.mendoza@ejemplo.com', phone_number: '+51912345678' },
      { name: 'Ana Lucía Rodríguez', email: 'ana.rodriguez@ejemplo.com', phone_number: '+51923456789' },
      { name: 'Diego Morales', email: 'diego.morales@ejemplo.com', phone_number: '+51934567890' },
      { name: 'Valentina Torres', email: 'valentina.torres@ejemplo.com', phone_number: '+51945678901' },
      { name: 'Fernando Gómez', email: 'fernando.gomez@ejemplo.com', phone_number: '+51956789012' },
      { name: 'Sofía Vargas', email: 'sofia.vargas@ejemplo.com', phone_number: '+51967890123' },
      { name: 'Jorge Silva', email: 'jorge.silva@ejemplo.com', phone_number: '+51978901234' },
      { name: 'Camila Ríos', email: 'camila.rios@ejemplo.com', phone_number: '+51989012345' },
      { name: 'Mateo Fernández', email: 'mateo.fernandez@ejemplo.com', phone_number: '+51990123456' }
    ]

    contacts = sample_contacts_data.map do |data|
      account.contacts.find_or_create_by!(email: data[:email]) do |c|
        c.name = data[:name]
        c.phone_number = data[:phone_number]
      end
    end
    puts "✅ #{contacts.count} contactos de prueba listos."

    # 3. Crear Canales y Bandejas de Entrada de Prueba (WhatsApp, Instagram, Facebook Messenger)
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

    # Asegurar que el usuario administrador esté asignado a todas las bandejas creadas
    account.inboxes.each do |inb|
      InboxMember.find_or_create_by!(inbox_id: inb.id, user_id: user.id) if user
    end

    sample_messages = [
      { msg: '¡Hola! Quisiera información sobre los planes de suscripción para mi negocio por WhatsApp.', inbox: inbox_wa },
      { msg: 'Buenas tardes, ¿tienen disponibilidad para agendar una demostración por Instagram?', inbox: inbox_ig },
      { msg: 'Hola, me gustaría saber si el CRM se puede conectar con mi fanpage de Facebook.', inbox: inbox_fb },
      { msg: '¿Cuáles son los métodos de pago disponibles? Me escribes al WhatsApp porfa.', inbox: inbox_wa },
      { msg: 'Hola, vi su historia de Instagram y me interesa instalar el sistema en mi tienda.', inbox: inbox_ig }
    ]

    contacts.first(5).each_with_index do |contact, idx|
      item = sample_messages[idx % sample_messages.length]
      target_inbox = item[:inbox]

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
        conv.assignee_id = user&.id
      end

      if conversation.messages.empty?
        conversation.messages.create!(
          account_id: account.id,
          inbox_id: target_inbox.id,
          content: item[:msg],
          message_type: :incoming,
          sender: contact
        )
      end
    end
    puts '✅ Conversaciones y mensajes multicanal (WhatsApp, Instagram, Facebook) generados con sus logos oficiales.'

    # 4. Crear Tratos (Deals) en el Embudo Kanban
    deals_data = [
      { name: 'Plan Anual Pizzería Bella', value: 1200, stage: stages[0], contact: contacts[0] },
      { name: 'Servicio CRM Barbería Club', value: 450, stage: stages[0], contact: contacts[1] },
      { name: 'Implementación Tienda Calzado', value: 850, stage: stages[1], contact: contacts[2] },
      { name: 'Consultoría Multicanal', value: 300, stage: stages[1], contact: contacts[3] },
      { name: 'Demostración Plataforma VIP', value: 1500, stage: stages[2], contact: contacts[4] },
      { name: 'Licencia 5 Usuarios Vendedores', value: 950, stage: stages[3], contact: contacts[5] },
      { name: 'Paquete Empresarial Completo', value: 2400, stage: stages[3], contact: contacts[6] },
      { name: 'Cierre de Contrato Anual', value: 3200, stage: stages[4], contact: contacts[7] },
      { name: 'Renovación de Licencia', value: 600, stage: stages[4], contact: contacts[8] }
    ]

    deals_data.each_with_index do |d, idx|
      Deal.find_or_create_by!(name: d[:name], account_id: account.id) do |deal|
        deal.value = d[:value]
        deal.pipeline_stage_id = d[:stage].id
        deal.contact_id = d[:contact].id
        deal.position = idx + 1
        deal.status = 'open'
      end
    end
    puts "✅ #{deals_data.count} tratos creados y distribuidos en el tablero Kanban."

    puts '🎉 ¡El CRM ahora está completamente poblado con datos multicanal de demostración!'
  end

  desc 'Limpiar todos los datos de prueba dejando la instalación 100% como nueva para un cliente'
  task limpiar: :environment do
    puts '🧹 Limpiando datos de prueba del CRM...'

    account = Account.first
    unless account
      puts '❌ No se encontró ninguna cuenta.'
      next
    end

    # 1. Borrar todos los tratos (Deals)
    deals_count = Deal.where(account_id: account.id).count
    Deal.where(account_id: account.id).destroy_all
    puts "🗑️ Se eliminaron #{deals_count} tratos del Kanban."

    # 2. Borrar mensajes y conversaciones
    conv_count = account.conversations.count
    account.conversations.destroy_all
    puts "🗑️ Se eliminaron #{conv_count} conversaciones de prueba."

    # 3. Borrar contactos de prueba
    contacts_count = account.contacts.count
    account.contacts.destroy_all
    puts "🗑️ Se eliminaron #{contacts_count} contactos."

    # 4. Borrar bandejas multicanal de prueba
    inboxes_count = account.inboxes.where.not(channel_type: 'Channel::WebWidget').count
    account.inboxes.where.not(channel_type: 'Channel::WebWidget').destroy_all
    puts "🗑️ Se eliminaron #{inboxes_count} bandejas multicanal de prueba."

    puts '✨ ¡El CRM ha sido limpiado por completo! Está listo como nuevo para entregárselo a tu cliente.'
  end
end
